import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DriftLocalDatabase extends GeneratedDatabase {
  DriftLocalDatabase._(super.executor);

  /// 按账号ID打开独立数据库
  static Future<DriftLocalDatabase> open({String? accountId}) async {
    final db = DriftLocalDatabase._(
      await _openConnection(accountId: accountId),
    );
    await db._initSchema();
    await db._seedDefaults();
    return db;
  }

  static Future<DriftLocalDatabase> inMemory() async {
    final db = DriftLocalDatabase._(NativeDatabase.memory());
    await db._initSchema();
    await db._seedDefaults();
    return db;
  }

  static Future<QueryExecutor> _openConnection({String? accountId}) async {
    final supportDir = await getApplicationSupportDirectory();
    await Directory(supportDir.path).create(recursive: true);
    // 不同账号用不同数据库文件
    final dbName = accountId != null && accountId.isNotEmpty
        ? 'autotalk_$accountId.sqlite'
        : 'tg_ai_sales_desktop.sqlite';
    final file = File(p.join(supportDir.path, dbName));
    return NativeDatabase.createInBackground(file);
  }

  Future<void> _initSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        goal_stage TEXT NOT NULL,
        last_message_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS customer_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        segment TEXT NOT NULL,
        tags_json TEXT NOT NULL,
        last_contact_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS business_template_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scope_level TEXT NOT NULL,
        scope_target_id TEXT,
        template_name TEXT NOT NULL,
        version TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        imported_at INTEGER NOT NULL,
        diff_summary_json TEXT NOT NULL,
        template_json TEXT NOT NULL,
        UNIQUE(scope_level, scope_target_id, template_name, version)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sent_at INTEGER NOT NULL,
        risk_flag INTEGER NOT NULL,
        metadata_json TEXT,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_sent_at ON messages(sent_at)',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS action_policies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        level TEXT NOT NULL,
        rules_json TEXT NOT NULL,
        is_enabled INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS goal_state_logs (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        stage TEXT NOT NULL,
        event TEXT NOT NULL,
        note TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        stage TEXT NOT NULL,
        status TEXT NOT NULL,
        request_id TEXT,
        operator TEXT,
        channel TEXT,
        template_version TEXT,
        model TEXT,
        latency_ms INTEGER,
        detail_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id)
      )
    ''');

    await _ensureAuditLogColumns();

    await customStatement('''
      CREATE TABLE IF NOT EXISTS dispatch_guards (
        request_id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id)
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS knowledge_center_intel (
        id TEXT PRIMARY KEY,
        industry TEXT NOT NULL,
        template_name TEXT NOT NULL,
        trend_summary TEXT NOT NULL,
        price_band TEXT NOT NULL,
        competitor_highlights_json TEXT NOT NULL,
        weekly_suggestion TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(industry, template_name)
      )
    ''');

    // ── V2: 产品目录 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        base_price REAL NOT NULL,
        floor_price REAL NOT NULL,
        unit TEXT NOT NULL,
        features_json TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ── V2: 价格规则 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS price_rules (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        rule_name TEXT NOT NULL,
        discount_percent REAL NOT NULL,
        min_quantity INTEGER NOT NULL,
        max_quantity INTEGER NOT NULL,
        valid_from INTEGER NOT NULL,
        valid_to INTEGER NOT NULL,
        requires_approval INTEGER NOT NULL,
        approval_level TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');

    // ── V2: 谈判上下文 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS negotiation_contexts (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        stage TEXT NOT NULL,
        product_ids_json TEXT NOT NULL,
        customer_budget_low REAL,
        customer_budget_high REAL,
        our_offer_price REAL,
        customer_offer_price REAL,
        concession_count INTEGER NOT NULL,
        max_concessions INTEGER NOT NULL,
        deal_score REAL NOT NULL,
        key_objections_json TEXT NOT NULL,
        agreed_terms_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_negotiation_conv ON negotiation_contexts(conversation_id)',
    );

    // ── V2: 升级告警 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS escalation_alerts (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        title TEXT NOT NULL,
        detail TEXT NOT NULL,
        suggested_action TEXT NOT NULL,
        resolved_by TEXT,
        resolved_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_escalation_status ON escalation_alerts(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_escalation_priority ON escalation_alerts(priority)',
    );

    // ── V2: 情绪记录 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sentiment_records (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        message_id TEXT NOT NULL,
        sentiment TEXT NOT NULL,
        confidence REAL NOT NULL,
        buying_signals_json TEXT NOT NULL,
        hesitation_signals_json TEXT NOT NULL,
        objection_patterns_json TEXT NOT NULL,
        emotion_tags_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id),
        FOREIGN KEY(message_id) REFERENCES messages(id)
      )
    ''');

    // ── V2: 订单表 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        items_json TEXT NOT NULL,
        total_amount REAL NOT NULL,
        currency TEXT NOT NULL,
        status TEXT NOT NULL,
        payment_method TEXT,
        delivery_method TEXT,
        delivery_info TEXT,
        notes TEXT,
        paid_at INTEGER,
        delivered_at INTEGER,
        completed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
    );

    // ── V2: 业务配置表 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS business_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        business_type TEXT NOT NULL,
        transaction_mode TEXT NOT NULL,
        delivery_method TEXT NOT NULL,
        persona_name TEXT NOT NULL,
        persona_style TEXT NOT NULL,
        persona_rules_json TEXT NOT NULL,
        greeting_template TEXT NOT NULL,
        quote_template TEXT NOT NULL,
        closing_template TEXT NOT NULL,
        price_inquiry_keywords_json TEXT NOT NULL,
        buy_intent_keywords_json TEXT NOT NULL,
        risk_keywords_json TEXT NOT NULL,
        currency TEXT NOT NULL,
        auto_quote_enabled INTEGER NOT NULL,
        quick_reply_enabled INTEGER NOT NULL,
        is_active INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ── V4: 话术库 ──
    await customStatement('''
      CREATE TABLE IF NOT EXISTS script_templates (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tags_json TEXT NOT NULL,
        use_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ── V3: products 新增交易字段 ──
    await _ensureProductColumns();
    // ── V2: conversations 新增列 ──
    await _ensureConversationColumns();
    // ── V2: customer_profiles 新增商业字段 ──
    await _ensureCustomerProfileColumns();
  }

  Future<void> _ensureProductColumns() async {
    final rows = await customSelect(
      "PRAGMA table_info('products')",
      readsFrom: {},
    ).get();
    final existing = rows.map((e) => e.read<String>('name')).toSet();

    Future<void> addCol(String name, String sqlType) async {
      if (existing.contains(name)) return;
      await customStatement('ALTER TABLE products ADD COLUMN $name $sqlType');
      existing.add(name);
    }

    await addCol('transaction_type', "TEXT DEFAULT 'oneTime'");
    await addCol('stock', 'INTEGER');
    await addCol('delivery_method', "TEXT DEFAULT 'digital'");
    await addCol('tags_json', "TEXT DEFAULT '[]'");
  }

  Future<void> _ensureCustomerProfileColumns() async {
    final rows = await customSelect(
      "PRAGMA table_info('customer_profiles')",
      readsFrom: {},
    ).get();
    final existing = rows.map((e) => e.read<String>('name')).toSet();

    Future<void> addCol(String name, String sqlType) async {
      if (existing.contains(name)) return;
      await customStatement(
        'ALTER TABLE customer_profiles ADD COLUMN $name $sqlType',
      );
      existing.add(name);
    }

    await addCol('company', 'TEXT');
    await addCol('email', 'TEXT');
    await addCol('phone', 'TEXT');
    await addCol('industry', 'TEXT');
    await addCol('budget_level', 'TEXT');
    await addCol('is_decision_maker', 'INTEGER DEFAULT 0');
    await addCol('life_cycle_stage', "TEXT DEFAULT 'lead'");
    await addCol('risk_score', 'INTEGER DEFAULT 0');
    await addCol('notes', 'TEXT');
    await addCol('preferred_channel', 'TEXT');
    await addCol('total_revenue', 'REAL DEFAULT 0');
  }

  Future<void> _ensureConversationColumns() async {
    final rows = await customSelect(
      "PRAGMA table_info('conversations')",
      readsFrom: {},
    ).get();
    final existing = rows.map((e) => e.read<String>('name')).toSet();
    if (!existing.contains('autopilot_mode')) {
      await customStatement(
        "ALTER TABLE conversations ADD COLUMN autopilot_mode TEXT DEFAULT 'manual'",
      );
    }
    if (!existing.contains('negotiation_id')) {
      await customStatement(
        'ALTER TABLE conversations ADD COLUMN negotiation_id TEXT',
      );
    }
  }

  Future<void> _ensureAuditLogColumns() async {
    final rows = await customSelect(
      "PRAGMA table_info('audit_logs')",
      readsFrom: {},
    ).get();
    final existing = rows.map((e) => e.read<String>('name')).toSet();

    Future<void> addColumnIfMissing(String name, String sqlType) async {
      if (existing.contains(name)) return;
      await customStatement('ALTER TABLE audit_logs ADD COLUMN $name $sqlType');
      existing.add(name);
    }

    await addColumnIfMissing('request_id', 'TEXT');
    await addColumnIfMissing('operator', 'TEXT');
    await addColumnIfMissing('channel', 'TEXT');
    await addColumnIfMissing('template_version', 'TEXT');
    await addColumnIfMissing('model', 'TEXT');
    await addColumnIfMissing('latency_ms', 'INTEGER');

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_request_id ON audit_logs(request_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_channel ON audit_logs(channel)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at)',
    );
  }

  Future<void> _seedDefaults() async {
    await _seedActionPolicies();
    await _seedBusinessProfiles();
    await _seedKnowledgeCenterIntel();
  }

  Future<void> _seedActionPolicies() async {
    final hasPolicy = await customSelect(
      'SELECT COUNT(1) c FROM action_policies',
      readsFrom: {},
    ).getSingle();
    if ((hasPolicy.read<int>('c')) > 0) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT INTO action_policies(id,name,level,rules_json,is_enabled,updated_at) VALUES (?,?,?,?,?,?)',
      [
        'default_policy',
        '默认风控策略',
        'L1',
        jsonEncode(['敏感词触发人工复核', '高风险会话自动降级为草稿']),
        1,
        now,
      ],
    );
  }

  Future<void> _seedBusinessProfiles() async {
    final has = await customSelect(
      'SELECT COUNT(1) c FROM business_profiles',
      readsFrom: {},
    ).getSingle();
    if ((has.read<int>('c')) > 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // SaaS 销售配置
    await customStatement(
      '''INSERT INTO business_profiles(id,name,business_type,transaction_mode,delivery_method,
        persona_name,persona_style,persona_rules_json,greeting_template,quote_template,closing_template,
        price_inquiry_keywords_json,buy_intent_keywords_json,risk_keywords_json,
        currency,auto_quote_enabled,quick_reply_enabled,is_active,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        'bp_default_sales',
        'SaaS销售',
        'sales',
        'subscription',
        'digital',
        '小助',
        '专业简洁，目标导向，温和有推动力',
        jsonEncode(['先建立信任再谈业务', '价格讨论时先强调价值再报价', '不承诺绝对性结果']),
        '您好！感谢关注，我是{persona}，有什么可以帮您的？',
        '这个方案{product}的价格是{price}/{unit}，现在还有优惠活动~',
        '好的，那我这边安排合同流程，您确认下信息~',
        jsonEncode(['价格', '报价', '多少钱', '费用', '收费', '套餐', '怎么收']),
        jsonEncode(['购买', '下单', '开通', '合同', '签约', '付款', '试用']),
        jsonEncode(['投诉', '退款', '举报', '维权', '骗', '差评']),
        '¥',
        0,
        0,
        1,
        now,
        now,
      ],
    );

    // 资源交易配置
    await customStatement(
      '''INSERT INTO business_profiles(id,name,business_type,transaction_mode,delivery_method,
        persona_name,persona_style,persona_rules_json,greeting_template,quote_template,closing_template,
        price_inquiry_keywords_json,buy_intent_keywords_json,risk_keywords_json,
        currency,auto_quote_enabled,quick_reply_enabled,is_active,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        'bp_default_trading',
        '资源交易',
        'trading',
        'negotiable',
        'digital',
        '老板',
        '简洁直接，老练不废话，报价干脆',
        jsonEncode([
          '直接报价不啰嗦',
          '客户问什么答什么不主动推销',
          '确认付款后才发货',
          '不透露货源和成本',
          '遇到砍价适当让步但有底线',
        ]),
        '在的，需要什么？',
        '{product} {price}{currency}，要的话说一声',
        '好，{price}{currency}，付了我马上发',
        jsonEncode([
          '多少钱',
          '怎么卖',
          '什么价',
          '价格',
          '收吗',
          '有没有',
          '多少',
          '几块',
          '贵不贵',
          '便宜',
          '打包价',
          '怎么收',
          '报个价',
        ]),
        jsonEncode([
          '要了',
          '来一个',
          '买',
          '要',
          '付了',
          '转了',
          '发我',
          '给我',
          '拿',
          '下单',
          '可以',
          '行',
          '成交',
        ]),
        jsonEncode(['骗子', '举报', '报警', '假的', '骗', '投诉', '退钱']),
        '¥',
        1,
        1,
        0,
        now,
        now,
      ],
    );
  }

  Future<void> _seedKnowledgeCenterIntel() async {
    final has = await customSelect(
      'SELECT COUNT(1) c FROM knowledge_center_intel',
      readsFrom: {},
    ).getSingle();
    if ((has.read<int>('c')) > 0) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      '''INSERT INTO knowledge_center_intel(
        id,industry,template_name,trend_summary,price_band,
        competitor_highlights_json,weekly_suggestion,updated_at
      ) VALUES (?,?,?,?,?,?,?,?)''',
      [
        'intel_seed_cross_border_saas_discover',
        '跨境电商SaaS',
        'discover',
        '商家关注获客效率与自动化运营，偏好可快速落地的方案。',
        '¥1999-¥8999/月',
        jsonEncode(['竞品A强化自动化触达', '竞品B主打低门槛试用']),
        '先确认当前投放与私域转化瓶颈，再给出两档可执行套餐。',
        now,
      ],
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  int get schemaVersion => 1;
}
