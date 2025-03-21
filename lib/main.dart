import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum GamePhase { Preflop, Flop, Turn, River, Showdown }

class CardModel {
  final String suit;
  final String rank;

  CardModel({required this.suit, required this.rank});

  String get paddedRank {
    final numeric = int.tryParse(rank);
    if (numeric != null && rank.length == 1) {
      return numeric.toString().padLeft(2, '0');
    }
    return rank;
  }

  String get imageName => 'card_${suit.toLowerCase()}_${paddedRank.toUpperCase()}.png';
}

class Deck {
  final List<CardModel> cards = [];

  Deck() {
    const suits = ['clubs', 'diamonds', 'hearts', 'spades'];
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    for (var suit in suits) {
      for (var rank in ranks) {
        cards.add(CardModel(suit: suit, rank: rank));
      }
    }
  }

  void shuffle() {
    cards.shuffle(Random());
  }

  CardModel dealCard() => cards.removeLast();
}

class GamePlayer {
  final String id;
  int money;
  List<CardModel> hand;
  bool folded;

  GamePlayer({required this.id, this.money = 1000, List<CardModel>? hand, this.folded = false})
      : hand = hand ?? [];
}

/// Rank values for hand evaluation.
const Map<String, int> rankValues = {
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
  '10': 10,
  'J': 11,
  'Q': 12,
  'K': 13,
  'A': 14,
};

/// Generate a random 6-character join code.
String generateJoinCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
}

/// MAIN
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vzzunozvverrorshindf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6enVub3p2dmVycm9yc2hpbmRmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0MDIyNDUsImV4cCI6MjA1Nzk3ODI0NX0.2DhqtwQP9CJyXUp7Ayqnsmz4wmFsvvRTXSS0Ju_htXs',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Texas Hold’em',
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/create': (context) => const CreateRoomPage(),
        '/join': (context) => const JoinRoomPage(),
        '/game': (context) => const GamePage(),
      },
    );
  }
}

/// Home Screen: Choose to create or join a room.
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Texas Hold’em Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Create Room'),
              onPressed: () => Navigator.pushNamed(context, '/create'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Join Room'),
              onPressed: () => Navigator.pushNamed(context, '/join'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create Room Screen.
class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});
  @override
  _CreateRoomPageState createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isPrivate = true;
  bool _isLoading = false;
  final String _userId = "user-123"; // Replace with your user identification logic.

  Future<void> _createRoom() async {
    final roomName = _nameController.text.trim();
    if (roomName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter a room name")));
      return;
    }
    setState(() => _isLoading = true);
    final joinCode = generateJoinCode();
    try {
      final List<dynamic> roomResponse = await Supabase.instance.client
          .from('rooms')
          .insert({
        'name': roomName,
        'owner_id': _userId,
        'private': _isPrivate,
        'join_code': joinCode,
      }).select();
      if (roomResponse.isEmpty) throw Exception("Room creation failed.");
      final room = roomResponse[0];
      // Insert the creator into room_members.
      await Supabase.instance.client.from('room_members').insert({
        'room_id': room['id'],
        'user_id': _userId,
      }).select();
      setState(() => _isLoading = false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/game', arguments: {
        'roomId': room['id'],
        'isHost': true,
        'joinCode': joinCode,
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Room Name'),
            ),
            SwitchListTile(
              title: const Text('Private Room'),
              value: _isPrivate,
              onChanged: (val) => setState(() => _isPrivate = val),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    child: const Text('Create'),
                    onPressed: _createRoom,
                  ),
          ],
        ),
      ),
    );
  }
}

/// Join Room Screen.
class JoinRoomPage extends StatefulWidget {
  const JoinRoomPage({super.key});
  @override
  _JoinRoomPageState createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  final TextEditingController _joinCodeController = TextEditingController();
  bool _isLoading = false;
  final String _userId = "user-456"; // Replace with your user identification logic.

  Future<void> _joinRoom() async {
    final joinCode = _joinCodeController.text.trim();
    if (joinCode.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter a join code")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final roomResponse = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('join_code', joinCode)
          .maybeSingle();
      if (roomResponse == null)
        throw Exception("Room not found. Check join code.");
      final roomId = roomResponse['id'];
      await Supabase.instance.client.from('room_members').insert({
        'room_id': roomId,
        'user_id': _userId,
      }).select();
      setState(() => _isLoading = false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/game', arguments: {
        'roomId': roomId,
        'isHost': false,
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(labelText: 'Join Code'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    child: const Text('Join'),
                    onPressed: _joinRoom,
                  ),
          ],
        ),
      ),
    );
  }
}

/// Game Screen: Handles game state, turn order, and realtime player updates.
class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late String roomId;
  late bool isHost;
  String? joinCode; // Only provided for host.
  GamePhase phase = GamePhase.Preflop;
  int currentBet = 0;
  int potTotal = 0;
  List<CardModel> communityCardsFull = [];
  List<CardModel> communityCardsDisplayed = [];
  List<GamePlayer> players = [];
  final String currentUserId = "user-123";
  late Deck deck;

  // Turn and betting variables.
  int currentPlayerIndex = 0;
  Map<String, int> roundBets = {};
  bool bettingRoundActive = true;
  final TextEditingController _betController = TextEditingController();
  bool gameStarted = false;

  // Stream subscription for realtime updates.
  StreamSubscription<List<dynamic>>? _roomSubscription;

  @override
  void initState() {
    super.initState();
    deck = Deck();
    deck.shuffle();
    // Pre-deal five community cards.
    communityCardsFull = List.generate(5, (_) => deck.dealCard());
    communityCardsDisplayed =
        List.generate(5, (_) => CardModel(suit: '', rank: 'BACK'));
    roundBets[currentUserId] = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    roomId = args['roomId'];
    isHost = args['isHost'];
    if (isHost && args.containsKey('joinCode')) {
      joinCode = args['joinCode'];
    }
    // Initially fetch room members.
    _fetchRoomMembers();
    // Subscribe to realtime updates using the stream API.
    _subscribeToRoomMembers();
  }

  Future<void> _fetchRoomMembers() async {
    final response = await Supabase.instance.client
        .from('room_members')
        .select()
        .eq('room_id', roomId);
    if (response != null) {
      final members = response as List;
      setState(() {
        players = members.map((m) => GamePlayer(id: m['user_id'])).toList();
        // Ensure current user is present.
        if (!players.any((p) => p.id == currentUserId)) {
          players.add(GamePlayer(id: currentUserId));
        }
      });
    }
  }

  void _subscribeToRoomMembers() {
    _roomSubscription = Supabase.instance.client
        .from('room_members:room_id=eq.$roomId')
        .stream(primaryKey: ['id'])
        .listen((data) {
      setState(() {
        players = data.map((m) => GamePlayer(id: m['user_id'])).toList();
        if (!players.any((p) => p.id == currentUserId)) {
          players.add(GamePlayer(id: currentUserId));
        }
      });
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _updateCommunityCards() {
    setState(() {
      if (phase == GamePhase.Preflop) {
        communityCardsDisplayed =
            List.generate(5, (_) => CardModel(suit: '', rank: 'BACK'));
      } else if (phase == GamePhase.Flop) {
        communityCardsDisplayed = [
          communityCardsFull[0],
          communityCardsFull[1],
          communityCardsFull[2],
          CardModel(suit: '', rank: 'BACK'),
          CardModel(suit: '', rank: 'BACK'),
        ];
      } else if (phase == GamePhase.Turn) {
        communityCardsDisplayed = [
          communityCardsFull[0],
          communityCardsFull[1],
          communityCardsFull[2],
          communityCardsFull[3],
          CardModel(suit: '', rank: 'BACK'),
        ];
      } else if (phase == GamePhase.River || phase == GamePhase.Showdown) {
        communityCardsDisplayed = communityCardsFull;
      }
    });
  }

  Future<void> _makeBet(int amount) async {
    GamePlayer player = players[currentPlayerIndex];
    if (amount <= 0 || player.money < amount) return;
    setState(() {
      player.money -= amount;
      roundBets[player.id] = (roundBets[player.id] ?? 0) + amount;
      potTotal += amount;
      if ((roundBets[player.id] ?? 0) > currentBet) {
        currentBet = roundBets[player.id]!;
      }
    });
    _advanceTurn();
  }

  Future<void> _call() async {
    GamePlayer player = players[currentPlayerIndex];
    int needed = currentBet - (roundBets[player.id] ?? 0);
    if (needed <= 0 || player.money < needed) return;
    setState(() {
      player.money -= needed;
      roundBets[player.id] = (roundBets[player.id] ?? 0) + needed;
      potTotal += needed;
    });
    _advanceTurn();
  }

  void _check() {
    if ((roundBets[players[currentPlayerIndex].id] ?? 0) == currentBet) {
      _advanceTurn();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must call or bet instead of checking.")));
    }
  }

  void _fold() {
    setState(() {
      players[currentPlayerIndex].folded = true;
    });
    _advanceTurn();
  }

  void _advanceTurn() {
    if (!_isBettingRoundComplete() || players.length < 2) return;
    bettingRoundActive = false;
    Future.delayed(const Duration(seconds: 1), _nextPhase);
  }

  bool _isBettingRoundComplete() {
    int? target;
    for (var player in players) {
      if (player.folded) continue;
      int bet = roundBets[player.id] ?? 0;
      target ??= bet;
      if (bet != target) return false;
    }
    return true;
  }

  void _resetBettingRound() {
    currentBet = 0;
    bettingRoundActive = true;
    for (var player in players) {
      roundBets[player.id] = 0;
    }
    currentPlayerIndex = 0;
  }

  int evaluateHand(GamePlayer player) {
    // For simplicity, highest card wins.
    List<CardModel> available = []..addAll(player.hand);
    if (phase == GamePhase.River || phase == GamePhase.Showdown) {
      available.addAll(communityCardsFull);
    }
    int best = 0;
    for (var card in available) {
      if (card.rank == 'BACK' || card.rank.isEmpty) continue;
      best = max(best, rankValues[card.rank] ?? 0);
    }
    return best;
  }

  void _determineWinners() {
    List<GamePlayer> contenders = players.where((p) => !p.folded).toList();
    if (contenders.isEmpty) return;
    int bestScore = 0;
    List<GamePlayer> winners = [];
    for (var player in contenders) {
      int score = evaluateHand(player);
      if (score > bestScore) {
        bestScore = score;
        winners = [player];
      } else if (score == bestScore) {
        winners.add(player);
      }
    }
    int share = (potTotal / winners.length).floor();
    for (var winner in winners) {
      winner.money += share;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Showdown'),
        content: Text(
            'Winner(s): ${winners.map((w) => w.id).join(", ")} with high card value $bestScore.\nEach wins: \$$share'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _nextPhase() {
    setState(() {
      if (phase == GamePhase.Preflop) {
        phase = GamePhase.Flop;
      } else if (phase == GamePhase.Flop) {
        phase = GamePhase.Turn;
      } else if (phase == GamePhase.Turn) {
        phase = GamePhase.River;
      } else if (phase == GamePhase.River) {
        phase = GamePhase.Showdown;
        _determineWinners();
      }
      _updateCommunityCards();
      if (phase != GamePhase.Showdown) _resetBettingRound();
    });
  }

  Future<void> _showBetDialog(String action) async {
    _betController.clear();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$action Amount'),
          content: TextField(
            controller: _betController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter amount'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                int amount = int.tryParse(_betController.text.trim()) ?? 0;
                Navigator.of(context).pop();
                if (action == 'Bet' || action == 'Raise') _makeBet(amount);
              },
              child: const Text('Submit'),
            )
          ],
        );
      },
    );
  }

  String _cardImagePath(CardModel card) {
    if (card.rank == 'BACK') return 'assets/images/card_back.png';
    return 'assets/images/${card.imageName}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const tableHeight = 400.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(isHost && joinCode != null ? 'Room: $roomId | Code: $joinCode' : 'Room: $roomId'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Pot: \$$potTotal    Current Bet: \$$currentBet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Phase: ${phase.toString().split('.').last}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            if (!gameStarted)
              isHost
                  ? (players.length > 1
                      ? ElevatedButton(
                          onPressed: () {
                            setState(() {
                              gameStarted = true;
                              _resetBettingRound();
                              // Optionally assign cards to each player.
                              // Here we only assign two cards to the host.
                              players.firstWhere((p) => p.id == currentUserId).hand =
                                  [deck.dealCard(), deck.dealCard()];
                            });
                          },
                          child: const Text('Start Game'),
                        )
                      : const Text('Waiting for opponents...',
                          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)))
                  : const Text('Waiting for host to start the game...',
                      style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic))
            else ...[
              if (players.length > 1 && bettingRoundActive)
                Text('Current Turn: ${players[currentPlayerIndex].id}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: tableHeight,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: communityCardsDisplayed.map((card) {
                          return Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(_cardImagePath(card), width: 50),
                          );
                        }).toList(),
                      ),
                    ),
                    ...players.asMap().entries.map((entry) {
                      final index = entry.key;
                      final angle = (index / players.length) * 2 * pi;
                      const radius = 150.0;
                      final offsetX = radius * cos(angle);
                      final offsetY = radius * sin(angle);
                      final player = entry.value;
                      return Positioned(
                        left: (screenWidth / 2) + offsetX - 45,
                        top: (tableHeight / 2) + offsetY - 20,
                        child: Column(
                          children: [
                            Text('Player: ${player.id}'),
                            Text('Money: \$${player.money}'),
                            Row(
                              children: (player.id == currentUserId || phase == GamePhase.Showdown)
                                  ? player.hand.map((card) {
                                      return Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Image.asset(_cardImagePath(card), width: 40),
                                      );
                                    }).toList()
                                  : [
                                      Image.asset('assets/images/card_back.png', width: 40),
                                      const SizedBox(width: 4),
                                      Image.asset('assets/images/card_back.png', width: 40),
                                    ],
                            ),
                            Text('Bet: \$${roundBets[player.id] ?? 0}'),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (players.length > 1 && bettingRoundActive)
                (players[currentPlayerIndex].id == currentUserId)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                              onPressed: () => _showBetDialog('Bet'),
                              child: const Text('Bet')),
                          ElevatedButton(
                              onPressed: _call, child: const Text('Call')),
                          ElevatedButton(
                              onPressed: () => _showBetDialog('Raise'),
                              child: const Text('Raise')),
                          ElevatedButton(
                              onPressed: _fold, child: const Text('Fold')),
                          ElevatedButton(
                              onPressed: ((roundBets[players[currentPlayerIndex].id] ?? 0) ==
                                      currentBet)
                                  ? _check
                                  : null,
                              child: const Text('Check')),
                        ],
                      )
                    : const Text('Waiting for your turn...'),
              const SizedBox(height: 20),
              const Text('Your Cards:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: players
                    .firstWhere((p) => p.id == currentUserId, orElse: () => GamePlayer(id: currentUserId))
                    .hand
                    .map((card) {
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(_cardImagePath(card), width: 60),
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
