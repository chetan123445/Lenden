import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../api_config.dart';
import '../user/session.dart';

class AdminFeaturesPage extends StatefulWidget {
  @override
  _AdminFeaturesPageState createState() => _AdminFeaturesPageState();
}

class _AdminFeaturesPageState extends State<AdminFeaturesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Features'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Plans'),
            Tab(text: 'Benefits'),
            Tab(text: 'FAQs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SubscriptionPlansTab(),
          PremiumBenefitsTab(),
          FaqsTab(),
        ],
      ),
    );
  }
}

// Models
class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int duration;
  final List<String> features;
  final bool isAvailable;
  final String? offer;

  SubscriptionPlan({required this.id, required this.name, required this.price, required this.duration, required this.features, required this.isAvailable, this.offer});

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'],
      name: json['name'],
      price: json['price'].toDouble(),
      duration: json['duration'],
      features: List<String>.from(json['features']),
      isAvailable: json['isAvailable'],
      offer: json['offer'],
    );
  }
}

class PremiumBenefit {
  final String id;
  final String text;

  PremiumBenefit({required this.id, required this.text});

  factory PremiumBenefit.fromJson(Map<String, dynamic> json) {
    return PremiumBenefit(
      id: json['_id'],
      text: json['text'],
    );
  }
}

class Faq {
  final String id;
  final String question;
  final String answer;

  Faq({required this.id, required this.question, required this.answer});

  factory Faq.fromJson(Map<String, dynamic> json) {
    return Faq(
      id: json['_id'],
      question: json['question'],
      answer: json['answer'],
    );
  }
}

// Subscription Plans Tab
class SubscriptionPlansTab extends StatefulWidget {
  @override
  _SubscriptionPlansTabState createState() => _SubscriptionPlansTabState();
}

class _SubscriptionPlansTabState extends State<SubscriptionPlansTab> {
  List<SubscriptionPlan> _plans = [];
  Map<String, bool> _isToggling = {};

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/subscription-plans'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _plans = data.map((item) => SubscriptionPlan.fromJson(item)).toList();
      });
    } else {
      // Handle error
    }
  }

  Future<void> _togglePlanAvailability(SubscriptionPlan plan, bool isAvailable) async {
    setState(() {
      _isToggling[plan.id] = true;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/subscription-plans/${plan.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': plan.name,
          'price': plan.price,
          'duration': plan.duration,
          'features': plan.features,
          'isAvailable': isAvailable,
        }),
      );

      if (response.statusCode == 200) {
        _fetchPlans();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan availability updated successfully')),
        );
      } else {
        final responseBody = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update plan availability: $responseBody')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isToggling[plan.id] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];
          return ListTile(
            title: Text(plan.name),
            subtitle: Text('\₹${plan.price} for ${plan.duration} days'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isToggling[plan.id] ?? false
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: plan.isAvailable,
                        onChanged: (value) {
                          _togglePlanAvailability(plan, value);
                        },
                      ),
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showPlanDialog(plan: plan),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deletePlan(plan.id),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlanDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showPlanDialog({SubscriptionPlan? plan}) {
    showDialog(
      context: context,
      builder: (context) {
        return PlanDialog(plan: plan, onSave: _fetchPlans);
      },
    );
  }

  Future<void> _deletePlan(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Plan'),
        content: Text('Are you sure you want to delete this plan?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/subscription-plans/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchPlans();
      } else {
        // Handle error
      }
    }
  }
}

class PlanDialog extends StatefulWidget {
  final SubscriptionPlan? plan;
  final VoidCallback onSave;

  PlanDialog({this.plan, required this.onSave});

  @override
  _PlanDialogState createState() => _PlanDialogState();
}

class _PlanDialogState extends State<PlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _price;
  late int _duration;
  late List<String> _features;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.plan?.name ?? '';
    _price = widget.plan?.price ?? 0.0;
    _duration = widget.plan?.duration ?? 0;
    _features = widget.plan?.features ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plan == null ? 'Add Plan' : 'Edit Plan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                initialValue: _price.toString(),
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
                onSaved: (value) => _price = double.parse(value!),
              ),
              TextFormField(
                initialValue: _duration.toString(),
                decoration: InputDecoration(labelText: 'Duration (days)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a duration' : null,
                onSaved: (value) => _duration = int.parse(value!),
              ),
              TextFormField(
                initialValue: _features.join(', '),
                decoration: InputDecoration(labelText: 'Features (comma separated)'),
                onSaved: (value) => _features = value!.split(', ').map((e) => e.trim()).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePlan,
          child: _isSaving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text('Save'),
        ),
      ],
    );
  }

  Future<void> _savePlan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final url = widget.plan == null
          ? '${ApiConfig.baseUrl}/api/admin/subscription-plans'
          : '${ApiConfig.baseUrl}/api/admin/subscription-plans/${widget.plan!.id}';
      final method = widget.plan == null ? 'POST' : 'PUT';

      try {
        final response = await http.Client().send(http.Request(method, Uri.parse(url))
          ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          ..body = json.encode({
            'name': _name,
            'price': _price,
            'duration': _duration,
            'features': _features,
          }));

        if (response.statusCode == 201 || response.statusCode == 200) {
          widget.onSave();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plan saved successfully')),
          );
        } else {
          final responseBody = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save plan: $responseBody')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }
}


// Premium Benefits Tab
class PremiumBenefitsTab extends StatefulWidget {
  @override
  _PremiumBenefitsTabState createState() => _PremiumBenefitsTabState();
}

class _PremiumBenefitsTabState extends State<PremiumBenefitsTab> {
    List<PremiumBenefit> _benefits = [];

  @override
  void initState() {
    super.initState();
    _fetchBenefits();
  }

  Future<void> _fetchBenefits() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/premium-benefits'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _benefits = data.map((item) => PremiumBenefit.fromJson(item)).toList();
      });
    } else {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _benefits.length,
        itemBuilder: (context, index) {
          final benefit = _benefits[index];
          return ListTile(
            title: Text(benefit.text),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showBenefitDialog(benefit: benefit),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteBenefit(benefit.id),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBenefitDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showBenefitDialog({PremiumBenefit? benefit}) {
    showDialog(
      context: context,
      builder: (context) {
        return BenefitDialog(benefit: benefit, onSave: _fetchBenefits);
      },
    );
  }

  Future<void> _deleteBenefit(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Benefit'),
        content: Text('Are you sure you want to delete this benefit?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/premium-benefits/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchBenefits();
      } else {
        // Handle error
      }
    }
  }
}

class BenefitDialog extends StatefulWidget {
  final PremiumBenefit? benefit;
  final VoidCallback onSave;

  BenefitDialog({this.benefit, required this.onSave});

  @override
  _BenefitDialogState createState() => _BenefitDialogState();
}

class _BenefitDialogState extends State<BenefitDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _text;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _text = widget.benefit?.text ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.benefit == null ? 'Add Benefit' : 'Edit Benefit'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          initialValue: _text,
          decoration: InputDecoration(labelText: 'Text'),
          validator: (value) => value!.isEmpty ? 'Please enter a text' : null,
          onSaved: (value) => _text = value!,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveBenefit,
          child: _isSaving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveBenefit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final url = widget.benefit == null
          ? '${ApiConfig.baseUrl}/api/admin/premium-benefits'
          : '${ApiConfig.baseUrl}/api/admin/premium-benefits/${widget.benefit!.id}';
      final method = widget.benefit == null ? 'POST' : 'PUT';

      try {
        final response = await http.Client().send(http.Request(method, Uri.parse(url))
          ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          ..body = json.encode({'text': _text}));

        if (response.statusCode == 201 || response.statusCode == 200) {
          widget.onSave();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Benefit saved successfully')),
          );
        } else {
          final responseBody = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save benefit: $responseBody')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }
}


// FAQs Tab
class FaqsTab extends StatefulWidget {
  @override
  _FaqsTabState createState() => _FaqsTabState();
}

class _FaqsTabState extends State<FaqsTab> {
  List<Faq> _faqs = [];

  @override
  void initState() {
    super.initState();
    _fetchFaqs();
  }

  Future<void> _fetchFaqs() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/faqs'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _faqs = data.map((item) => Faq.fromJson(item)).toList();
      });
    } else {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return ExpansionTile(
            title: Text(faq.question),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(faq.answer),
              )
            ],
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showFaqDialog(faq: faq),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteFaq(faq.id),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFaqDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showFaqDialog({Faq? faq}) {
    showDialog(
      context: context,
      builder: (context) {
        return FaqDialog(faq: faq, onSave: _fetchFaqs);
      },
    );
  }

  Future<void> _deleteFaq(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete FAQ'),
        content: Text('Are you sure you want to delete this FAQ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/faqs/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchFaqs();
      } else {
        // Handle error
      }
    }
  }
}

class FaqDialog extends StatefulWidget {
  final Faq? faq;
  final VoidCallback onSave;

  FaqDialog({this.faq, required this.onSave});

  @override
  _FaqDialogState createState() => _FaqDialogState();
}

class _FaqDialogState extends State<FaqDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _question;
  late String _answer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _question = widget.faq?.question ?? '';
    _answer = widget.faq?.answer ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.faq == null ? 'Add FAQ' : 'Edit FAQ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _question,
                decoration: InputDecoration(labelText: 'Question'),
                validator: (value) => value!.isEmpty ? 'Please enter a question' : null,
                onSaved: (value) => _question = value!,
              ),
              TextFormField(
                initialValue: _answer,
                decoration: InputDecoration(labelText: 'Answer'),
                validator: (value) => value!.isEmpty ? 'Please enter an answer' : null,
                onSaved: (value) => _answer = value!,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveFaq,
          child: _isSaving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveFaq() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final url = widget.faq == null
          ? '${ApiConfig.baseUrl}/api/admin/faqs'
          : '${ApiConfig.baseUrl}/api/admin/faqs/${widget.faq!.id}';
      final method = widget.faq == null ? 'POST' : 'PUT';

      try {
        final response = await http.Client().send(http.Request(method, Uri.parse(url))
          ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          ..body = json.encode({'question': _question, 'answer': _answer}));

        if (response.statusCode == 201 || response.statusCode == 200) {
          widget.onSave();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('FAQ saved successfully')),
          );
        } else {
          final responseBody = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save FAQ: $responseBody')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }
}