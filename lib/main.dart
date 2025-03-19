import 'package:flutter/material.dart';
import 'dart:math';

class Room {
  String code;
  double startingCash;
  List<String> players;
  String host;

  Room({required this.code, required this.startingCash, required this.host})
      : players = [host];

  void addPlayer(String playerName) {
    players.add(playerName);
  }
}

Room? currentRoom;
Map<String, Room> rooms = {};

class CardModel {
  final int value;
  final String suit;

  CardModel({required this.value, required this.suit});
}

CardModel parseCard(String cardStr) {
  String valueStr = cardStr.substring(0, cardStr.length - 1);
  String suit = cardStr.substring(cardStr.length - 1);
  int value;
  if (valueStr == 'J') {
    value = 11;
  } else if (valueStr == 'Q') {
    value = 12;
  } else if (valueStr == 'K') {
    value = 13;
  } else if (valueStr == 'A') {
    value = 14;
  } else {
    value = int.tryParse(valueStr) ?? 0;
  }
  return CardModel(value: value, suit: suit);
}

class HandValue implements Comparable<HandValue> {
  final int rank;
  final List<int> tiebreakers;

  HandValue(this.rank, this.tiebreakers);

  @override
  int compareTo(HandValue other) {
    if (rank != other.rank) return rank.compareTo(other.rank);
    for (int i = 0; i < tiebreakers.length && i < other.tiebreakers.length; i++) {
      if (tiebreakers[i] != other.tiebreakers[i]) {
        return tiebreakers[i].compareTo(other.tiebreakers[i]);
      }
    }
    return 0;
  }
}

List<List<T>> getCombinations<T>(List<T> list, int k) {
  List<List<T>> result = [];
  void combine(int start, List<T> current) {
    if (current.length == k) {
      result.add(List.from(current));
      return;
    }
    for (int i = start; i < list.length; i++) {
      current.add(list[i]);
      combine(i + 1, current);
      current.removeLast();
    }
  }
  combine(0, []);
  return result;
}

HandValue evaluateFiveCardHand(List<CardModel> hand) {
  hand.sort((a, b) => b.value.compareTo(a.value));
  List<int> values = hand.map((c) => c.value).toList();
  Map<int, int> freq = {};
  for (var v in values) {
    freq[v] = (freq[v] ?? 0) + 1;
  }
  bool isFlush = hand.every((c) => c.suit == hand[0].suit);

  List<int> uniqueValues = freq.keys.toList()..sort((a, b) => b.compareTo(a));
  bool isStraight = false;
  int straightHigh = 0;
  if (uniqueValues.length >= 5) {
    for (int i = 0; i <= uniqueValues.length - 5; i++) {
      List<int> seq = uniqueValues.sublist(i, i + 5);
      if (seq[0] - seq[4] == 4) {
        isStraight = true;
        straightHigh = seq[0];
        break;
      }
    }
    if (!isStraight && uniqueValues.contains(14)) {
      List<int> aceLow = List.from(uniqueValues);
      aceLow.remove(14);
      aceLow.add(1);
      aceLow.sort((a, b) => b.compareTo(a));
      for (int i = 0; i <= aceLow.length - 5; i++) {
        List<int> seq = aceLow.sublist(i, i + 5);
        if (seq[0] - seq[4] == 4) {
          isStraight = true;
          straightHigh = seq[0] == 1 ? 5 : seq[0];
          break;
        }
      }
    }
  }

  if (isFlush && isStraight) return HandValue(8, [straightHigh]);
  if (freq.values.contains(4)) {
    int quad = freq.keys.firstWhere((v) => freq[v] == 4);
    int kicker = freq.keys.where((v) => v != quad).fold(0, max);
    return HandValue(7, [quad, kicker]);
  }
  if (freq.values.contains(3) && freq.values.contains(2) ||
      freq.values.where((v) => v == 3).length >= 2) {
    List<int> trips = freq.keys.where((v) => freq[v]! >= 3).toList()..sort((a, b) => b.compareTo(a));
    List<int> pairs = freq.keys.where((v) => freq[v]! >= 2 && v != trips.first).toList()..sort((a, b) => b.compareTo(a));
    int trip = trips.first;
    int pair = pairs.isNotEmpty ? pairs.first : trips.length > 1 ? trips[1] : 0;
    return HandValue(6, [trip, pair]);
  }
  if (isFlush) return HandValue(5, values.sublist(0, 5));
  if (isStraight) return HandValue(4, [straightHigh]);
  if (freq.values.contains(3)) {
    int trip = freq.keys.firstWhere((v) => freq[v] == 3);
    List<int> kickers = freq.keys.where((v) => v != trip).toList()..sort((a, b) => b.compareTo(a));
    return HandValue(3, [trip] + kickers.take(2).toList());
  }
  List<int> pairValues = freq.keys.where((v) => freq[v]! >= 2).toList()..sort((a, b) => b.compareTo(a));
  if (pairValues.length >= 2) {
    int highPair = pairValues[0];
    int lowPair = pairValues[1];
    int kicker = freq.keys.where((v) => v != highPair && v != lowPair).fold(0, max);
    return HandValue(2, [highPair, lowPair, kicker]);
  }
  if (freq.values.contains(2)) {
    int pair = freq.keys.firstWhere((v) => freq[v] == 2);
    List<int> kickers = freq.keys.where((v) => v != pair).toList()..sort((a, b) => b.compareTo(a));
    return HandValue(1, [pair] + kickers.take(3).toList());
  }
  return HandValue(0, values.take(5).toList());
}

HandValue evaluateHand(List<String> cardStrs) {
  List<CardModel> cards = cardStrs.map(parseCard).toList();
  List<List<CardModel>> combinations = getCombinations(cards, 5);
  HandValue best = evaluateFiveCardHand(combinations.first);
  for (var combo in combinations.skip(1)) {
    HandValue current = evaluateFiveCardHand(combo);
    if (current.compareTo(best) > 0) best = current;
  }
  return best;
}

class BettingRound {
  final List<String> players;
  int currentPlayerIndex = 0;
  double currentBet = 0;

  BettingRound(this.players);

  String getCurrentPlayer() => players[currentPlayerIndex];

  void nextPlayer() {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  }
}

void main() {
  runApp(TexasHoldemApp());
}

class TexasHoldemApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Texas Holdem',
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/create': (context) => CreateRoomScreen(),
        '/join': (context) => JoinRoomScreen(),
        '/lobby': (context) => LobbyScreen(),
        '/game': (context) => GameScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Texas Holdem')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: Text('Create Room'),
              onPressed: () => Navigator.pushNamed(context, '/create'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Join Room'),
              onPressed: () => Navigator.pushNamed(context, '/join'),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateRoomScreen extends StatefulWidget {
  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cashController = TextEditingController(text: "10000");
  String roomCode = '';

  String generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  @override
  void initState() {
    super.initState();
    roomCode = generateRoomCode();
  }

  void createRoom() {
    if (_formKey.currentState!.validate()) {
      String hostName = _nameController.text;
      double startingCash = double.tryParse(_cashController.text) ?? 1000;
      String roomCodeKey = roomCode.trim().toUpperCase();
      currentRoom = Room(code: roomCodeKey, startingCash: startingCash, host: hostName);
      rooms[roomCodeKey] = currentRoom!;
      Navigator.pushNamed(context, '/lobby');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Text('Room Code: $roomCode', style: TextStyle(fontSize: 20)),
              SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Your Name (Host)'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter your name' : null,
              ),
              TextFormField(
                controller: _cashController,
                decoration: InputDecoration(labelText: 'Starting Cash'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a starting cash amount';
                  if (double.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(child: Text('Create Room'), onPressed: createRoom),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinRoomScreen extends StatefulWidget {
  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  void joinRoom() {
    if (_formKey.currentState!.validate()) {
      String roomCodeInput = _roomCodeController.text.trim().toUpperCase();
      String playerName = _nameController.text;
      if (rooms.containsKey(roomCodeInput)) {
        currentRoom = rooms[roomCodeInput]!;
        currentRoom!.addPlayer(playerName);
        Navigator.pushNamed(context, '/lobby');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room not found or invalid code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _roomCodeController,
                decoration: InputDecoration(labelText: 'Room Code'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter the room code' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Your Name'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter your name' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(child: Text('Join Room'), onPressed: joinRoom),
            ],
          ),
        ),
      ),
    );
  }
}

class LobbyScreen extends StatelessWidget {
  void startGame(BuildContext context) {
    Navigator.pushNamed(context, '/game');
  }

  @override
  Widget build(BuildContext context) {
    bool isHost = (currentRoom != null && currentRoom!.players.first == currentRoom!.host);
    return Scaffold(
      appBar: AppBar(title: Text('Lobby - Room ${currentRoom?.code ?? ''}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: currentRoom == null
            ? Center(child: Text('No room found'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Players:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ...currentRoom!.players.map((player) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(player, style: TextStyle(fontSize: 18)),
                      )),
                  SizedBox(height: 20),
                  if (isHost)
                    ElevatedButton(child: Text('Start Game'), onPressed: () => startGame(context))
                  else
                    Text('Waiting for host to start the game...'),
                ],
              ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final List<String> deck = [
    '02D', '03D', '04D', '05D', '06D', '07D', '08D', '09D', '010D', 'JD', 'QD', 'KD', 'AD',
    '02H', '03H', '04H', '05H', '06H', '07H', '08H', '09H', '010H', 'JH', 'QH', 'KH', 'AH',
    '02C', '03C', '04C', '05C', '06C', '07C', '08C', '09C', '010C', 'JC', 'QC', 'KC', 'AC',
    '02S', '03S', '04S', '05S', '06S', '07S', '08S', '09S', '010S', 'JS', 'QS', 'KS', 'AS',
  ];
  List<String> shuffledDeck = [];
  Map<String, List<String>> playerCards = {};
  List<String> communityCards = [];
  List<bool> communityCardsFaceUp = [false, false, false, false, false];

  BettingRound? bettingRound;
  Set<String> foldedPlayers = {};
  Map<String, double> playerContributions = {};
  Map<String, double> roundStartContributions = {};
  Map<String, double> playerChips = {};
  int stage = 0;
  final TextEditingController _betController = TextEditingController();
  final TextEditingController _raiseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    startNewHand();
  }

  void startNewHand() {
    shuffledDeck = List.from(deck)..shuffle(Random());
    foldedPlayers.clear();
    playerContributions.clear();

    if (currentRoom != null) {
      for (var player in currentRoom!.players) {
        if (!playerChips.containsKey(player)) {
          playerChips[player] = currentRoom!.startingCash;
        }
      }
    }

    dealCards();
    communityCards = List.generate(5, (_) => shuffledDeck.removeAt(0));
    communityCardsFaceUp = [false, false, false, false, false];
    stage = 0;
    resetBettingRound();
  }

  void dealCards() {
    if (currentRoom != null) {
      for (var player in currentRoom!.players) {
        playerCards[player] = [shuffledDeck.removeAt(0), shuffledDeck.removeAt(0)];
      }
    }
  }

  void resetBettingRound() {
    List<String> activePlayers = currentRoom!.players.where((p) => !foldedPlayers.contains(p)).toList();
    setState(() {
      bettingRound = BettingRound(activePlayers);
      bettingRound!.currentBet = 0;
      roundStartContributions.clear();
      for (var p in activePlayers) {
        roundStartContributions[p] = playerContributions[p] ?? 0;
      }
    });
  }

  void advanceStage() {
    setState(() {
      if (stage == 0) {
        communityCardsFaceUp[0] = true;
        communityCardsFaceUp[1] = true;
        communityCardsFaceUp[2] = true;
        stage = 1;
        resetBettingRound();
      } else if (stage == 1) {
        communityCardsFaceUp[3] = true;
        stage = 2;
        resetBettingRound();
      } else if (stage == 2) {
        communityCardsFaceUp[4] = true;
        stage = 3;
        resetBettingRound();
      } else if (stage == 3) {
        showResults();
      }
    });
  }

  double callAmount(String player) {
    double currentRoundContribution = (playerContributions[player] ?? 0) - (roundStartContributions[player] ?? 0);
    return bettingRound!.currentBet - currentRoundContribution;
  }

  void onBetPlaced(double amount) {
    if (bettingRound != null) {
      String currentPlayer = bettingRound!.getCurrentPlayer();
      if (playerChips[currentPlayer]! >= amount) {
        playerChips[currentPlayer] = playerChips[currentPlayer]! - amount;
        playerContributions[currentPlayer] =
            (playerContributions[currentPlayer] ?? 0) + amount;
        bettingRound!.currentBet = amount;
        bettingRound!.nextPlayer();
        setState(() {});
        checkBettingRoundComplete();
      }
    }
  }

  void onCall() {
    if (bettingRound != null) {
      String currentPlayer = bettingRound!.getCurrentPlayer();
      double callAmt = callAmount(currentPlayer);
      if (playerChips[currentPlayer]! >= callAmt) {
        playerChips[currentPlayer] = playerChips[currentPlayer]! - callAmt;
        playerContributions[currentPlayer] =
            (playerContributions[currentPlayer] ?? 0) + callAmt;
        bettingRound!.nextPlayer();
        setState(() {});
        checkBettingRoundComplete();
      }
    }
  }

  void onRaise(double raiseAmt) {
    if (bettingRound != null) {
      String currentPlayer = bettingRound!.getCurrentPlayer();
      double callAmt = callAmount(currentPlayer);
      double totalRequired = callAmt + raiseAmt;
      if (playerChips[currentPlayer]! >= totalRequired) {
        playerChips[currentPlayer] = playerChips[currentPlayer]! - totalRequired;
        playerContributions[currentPlayer] =
            (playerContributions[currentPlayer] ?? 0) + totalRequired;
        bettingRound!.currentBet = bettingRound!.currentBet + raiseAmt;
        bettingRound!.nextPlayer();
        setState(() {});
        checkBettingRoundComplete();
      }
    }
  }

  void onFold() {
    if (bettingRound != null) {
      String currentPlayer = bettingRound!.getCurrentPlayer();
      foldedPlayers.add(currentPlayer);
      bettingRound!.nextPlayer();
      setState(() {});
      checkBettingRoundComplete();
    }
  }

  void onCheck() {
    if (bettingRound != null) {
      String currentPlayer = bettingRound!.getCurrentPlayer();
      double callAmt = 0.0;
      if (playerChips[currentPlayer]! >= callAmt) {
        playerChips[currentPlayer] = playerChips[currentPlayer]! - callAmt;
        playerContributions[currentPlayer] =
            (playerContributions[currentPlayer] ?? 0) + callAmt;
        bettingRound!.nextPlayer();
        setState(() {});
        checkBettingRoundComplete();
      }
    }
  }

  void checkBettingRoundComplete() {
    if (bettingRound == null) return;
    bool complete = true;
    for (var player in bettingRound!.players) {
      if (foldedPlayers.contains(player)) continue;
      double contributed = (playerContributions[player] ?? 0) - (roundStartContributions[player] ?? 0);
      if (contributed != bettingRound!.currentBet) {
        complete = false;
        break;
      }
    }
    if (complete) {
      advanceStage();
    }
  }

  void showResults() {
    List<String> eligiblePlayers =
        currentRoom!.players.where((p) => !foldedPlayers.contains(p)).toList();

    Map<String, HandValue> handValues = {};
    for (var player in eligiblePlayers) {
      List<String> allCards = [];
      allCards.addAll(playerCards[player] ?? []);
      allCards.addAll(communityCards);
      handValues[player] = evaluateHand(allCards);
    }

    List<double> contribValues = playerContributions.values.toList()..sort();
    List<double> uniqueContribs = contribValues.toSet().toList()..sort();

    double previous = 0;
    Map<String, double> winnings = {for (var p in currentRoom!.players) p: 0.0};

    for (var threshold in uniqueContribs) {
      List<String> potPlayers =
          playerContributions.keys.where((p) => playerContributions[p]! >= threshold).toList();
      double potAmount = (threshold - previous) * potPlayers.length;
      previous = threshold;
      List<String> eligibleForPot =
          potPlayers.where((p) => !foldedPlayers.contains(p)).toList();
      if (eligibleForPot.isEmpty) continue;
      HandValue bestHand = handValues[eligibleForPot.first]!;
      for (var p in eligibleForPot.skip(1)) {
        if (handValues[p]!.compareTo(bestHand) > 0) bestHand = handValues[p]!;
      }
      List<String> winners = eligibleForPot.where((p) => handValues[p]!.compareTo(bestHand) == 0).toList();
      double share = potAmount / winners.length;
      for (var p in winners) {
        winnings[p] = (winnings[p] ?? 0) + share;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Hand Results"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: winnings.entries.map((entry) {
              String status = foldedPlayers.contains(entry.key) ? "Folded" : "Active";
              return Text("${entry.key} wins \$${entry.value.toStringAsFixed(2)} ($status)");
            }).toList(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                startNewHand();
              },
              child: Text("Next Hand"),
            )
          ],
        );
      },
    );
  }

  String getCardImagePath(String card) {
    String suit;
    String value = card.substring(0, card.length - 1);
    switch (card.substring(card.length - 1)) {
      case 'H':
        suit = 'hearts';
        break;
      case 'D':
        suit = 'diamonds';
        break;
      case 'C':
        suit = 'clubs';
        break;
      case 'S':
        suit = 'spades';
        break;
      default:
        suit = '';
    }
    if (value == '10' || value == '010') value = '10';
    else if (value == 'J') value = 'J';
    else if (value == 'Q') value = 'Q';
    else if (value == 'K') value = 'K';
    else if (value == 'A') value = 'A';
    else value = value.padLeft(2, '0');
    return 'assets/images/card_${suit}_$value.png';
  }

  @override
  Widget build(BuildContext context) {
    String currentPlayer = bettingRound?.getCurrentPlayer() ?? "";
    double currentChips = currentPlayer.isNotEmpty ? (playerChips[currentPlayer] ?? 0) : 0;
    double currentRoundContribution = currentPlayer.isNotEmpty
        ? (playerContributions[currentPlayer] ?? 0) - (roundStartContributions[currentPlayer] ?? 0)
        : 0;
    double callAmt = bettingRound != null ? bettingRound!.currentBet - currentRoundContribution : 0;

    return Scaffold(
      appBar: AppBar(title: Text('Texas Holdem Game')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Community Cards', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: communityCards.asMap().entries.map((entry) {
              int index = entry.key;
              String card = entry.value;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  communityCardsFaceUp[index]
                      ? getCardImagePath(card)
                      : 'assets/images/card_back.png',
                  width: 50,
                  height: 75,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),
          Text('Player Cards', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: currentRoom?.players.length ?? 0,
              itemBuilder: (context, index) {
                String player = currentRoom!.players[index];
                List<String>? cards = playerCards[player];
                return ListTile(
                  title: Text(
                      "$player (\$${(playerChips[player] ?? currentRoom!.startingCash).toStringAsFixed(2)})"),
                  subtitle: Row(
                    children: (cards ?? []).map((card) => Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            currentRoom!.host == player
                                ? getCardImagePath(card)
                                : 'assets/images/card_back.png',
                            width: 50,
                            height: 75,
                          ),
                        )).toList(),
                  ),
                );
              },
            ),
          ),
          Divider(),
          if (bettingRound != null && currentPlayer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Current Player: $currentPlayer', style: TextStyle(fontSize: 20)),
                  Text('Your Chips: \$${currentChips.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                  Text('Current Bet: \$${bettingRound!.currentBet.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                  Text('Call Amount: \$${callAmt.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              double betAmount = double.tryParse(_betController.text) ?? 0;
                              onBetPlaced(betAmount);
                              _betController.clear();
                            },
                            child: Text('Bet'),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _betController,
                              decoration: InputDecoration(labelText: 'Amount'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: onCall,
                        child: Text('Call'),
                      ),
                      SizedBox(width: 10),
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: bettingRound!.currentBet == 0
                                ? null
                                : () {
                                    double raiseAmt = double.tryParse(_raiseController.text) ?? 0;
                                    onRaise(raiseAmt);
                                    _raiseController.clear();
                                  },
                            child: Text('Raise'),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _raiseController,
                              decoration: InputDecoration(labelText: 'Amount'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: onFold,
                        child: Text('Fold'),
                      ),
                      SizedBox(width: 10),
                      if (bettingRound!.currentBet == 0)
                        ElevatedButton(
                          onPressed: onCheck,
                          child: Text('Check'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}