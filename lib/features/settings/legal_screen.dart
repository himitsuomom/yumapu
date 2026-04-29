// lib/features/settings/legal_screen.dart
//
// プライバシーポリシーと利用規約を表示する画面。
// App Store / Google Play の審査で必須となるため実装する。

import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
// プライバシーポリシー画面
// ──────────────────────────────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _LegalText(sections: _privacySections),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 利用規約画面
// ──────────────────────────────────────────────────────────────────────────────

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('利用規約')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _LegalText(sections: _termsSections),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 共通ウィジェット
// ──────────────────────────────────────────────────────────────────────────────

class _LegalText extends StatelessWidget {
  const _LegalText({required this.sections});

  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          if (section.title != null) ...[
            Text(
              section.title!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            section.body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.7, color: const Color(0xFF424242)),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _Section {
  const _Section({this.title, required this.body});
  final String? title;
  final String body;
}

// ──────────────────────────────────────────────────────────────────────────────
// プライバシーポリシー本文
// ──────────────────────────────────────────────────────────────────────────────

const _privacySections = [
  _Section(
    body: '湯マップ（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。本プライバシーポリシーは、本アプリが収集する情報とその利用方法について説明します。',
  ),
  _Section(
    title: '1. 収集する情報',
    body: '本アプリは以下の情報を収集することがあります。\n\n'
        '・メールアドレス（アカウント登録時）\n'
        '・表示名・ユーザー名・自己紹介（プロフィール設定時）\n'
        '・プロフィール画像・投稿画像（任意でアップロードした場合）\n'
        '・位置情報（地図機能使用時・ユーザーが許可した場合のみ）\n'
        '・投稿内容・レビュー・コメント（ユーザーが投稿した場合）\n'
        '・訪問記録・お気に入り情報（機能使用時）\n'
        '・アプリの利用状況（Firebase Analytics によるアクセス解析）\n'
        '・エラー情報（Sentry によるクラッシュレポート）',
  ),
  _Section(
    title: '2. 情報の利用目的',
    body: '収集した情報は以下の目的で利用します。\n\n'
        '・アカウントの作成・認証・管理\n'
        '・温泉・サウナ・銭湯施設の情報提供\n'
        '・ユーザー間のソーシャル機能（投稿・コメント・いいね）\n'
        '・アプリの品質向上・不具合対応\n'
        '・利用状況の分析によるサービス改善',
  ),
  _Section(
    title: '3. 第三者への提供',
    body: '本アプリは以下のサービスを利用しており、それぞれのプライバシーポリシーに従ってデータが処理されます。\n\n'
        '・Supabase（データベース・認証・ストレージ）\n'
        '・OpenStreetMap / Nominatim（地図表示・住所検索）\n'
        '・Firebase Analytics（利用状況分析）\n'
        '・Sentry（エラー監視）\n'
        '・RevenueCat（課金管理 — 有効化時のみ）\n'
        '・Google AdMob（広告配信 — 有効化時のみ）\n\n'
        '法令に基づく場合を除き、ユーザーの同意なしに第三者へ個人情報を提供することはありません。',
  ),
  _Section(
    title: '4. データの保管・削除',
    body: 'ユーザーデータはアカウントが存在する期間保管されます。アカウント削除を希望する場合は、アプリ内のお問い合わせ機能または下記の連絡先までご連絡ください。削除依頼を受け付けてから30日以内に個人情報を削除します。',
  ),
  _Section(
    title: '5. セキュリティ',
    body: '本アプリはSSL/TLS暗号化通信を使用し、個人情報の不正アクセス・漏洩・改ざんを防ぐための技術的措置を講じています。ただし、インターネット上の完全なセキュリティを保証するものではありません。',
  ),
  _Section(
    title: '6. 子どものプライバシー',
    body: '本アプリは13歳未満の子どもを対象としていません。13歳未満の方は本アプリをご利用いただけません。',
  ),
  _Section(
    title: '7. ポリシーの変更',
    body: '本ポリシーは予告なく変更される場合があります。重要な変更がある場合はアプリ内でお知らせします。',
  ),
  _Section(
    title: '8. お問い合わせ',
    body: 'プライバシーに関するご質問・ご要望は、アプリ内のお問い合わせ機能よりご連絡ください。\n\n最終更新: 2026年4月',
  ),
];

// ──────────────────────────────────────────────────────────────────────────────
// 利用規約本文
// ──────────────────────────────────────────────────────────────────────────────

const _termsSections = [
  _Section(
    body: '本利用規約（以下「本規約」）は、湯マップ（以下「本アプリ」）の利用条件を定めるものです。本アプリをご利用になる前に、本規約をよくお読みください。本アプリを利用することで、本規約に同意したものとみなします。',
  ),
  _Section(
    title: '1. サービスの利用',
    body: '本アプリは、温泉・サウナ・銭湯に関する情報の検索・共有を目的としたサービスです。個人的・非商業的な目的でのみご利用いただけます。',
  ),
  _Section(
    title: '2. アカウント',
    body: '一部の機能はアカウント登録が必要です。ユーザーは以下の責任を負います。\n\n'
        '・登録情報を正確に保つこと\n'
        '・パスワードを適切に管理し、第三者に開示しないこと\n'
        '・アカウントを使用した一切の行為について責任を持つこと',
  ),
  _Section(
    title: '3. 禁止事項',
    body: '以下の行為を禁止します。\n\n'
        '・他のユーザーや第三者を誹謗・中傷する投稿\n'
        '・虚偽の情報の投稿\n'
        '・著作権・肖像権等を侵害するコンテンツの投稿\n'
        '・スパムやなりすまし行為\n'
        '・不正アクセスやリバースエンジニアリング\n'
        '・法令や公序良俗に反する行為',
  ),
  _Section(
    title: '4. コンテンツ',
    body: 'ユーザーが投稿したレビュー・写真・コメント等の著作権はユーザー本人に帰属します。ただしユーザーは、本アプリおよびサービス改善のために当該コンテンツを無償で利用することを許諾するものとします。\n\n不適切なコンテンツは予告なく削除する場合があります。',
  ),
  _Section(
    title: '5. 免責事項',
    body: '本アプリが提供する施設情報・営業時間・料金等は最新でない場合があります。実際の情報は各施設に直接ご確認ください。\n\n本アプリの利用によって生じた損害について、法令の範囲内で責任を負いません。',
  ),
  _Section(
    title: '6. サービスの変更・停止',
    body: '本アプリは予告なしにサービス内容を変更・停止する場合があります。これによってユーザーに生じた損害について責任を負いません。',
  ),
  _Section(
    title: '7. 準拠法・管轄',
    body: '本規約は日本法に準拠します。本アプリに関する紛争については、日本国内の裁判所を管轄裁判所とします。',
  ),
  _Section(
    title: '8. お問い合わせ',
    body: 'ご不明な点はアプリ内のお問い合わせ機能よりご連絡ください。\n\n最終更新: 2026年4月',
  ),
];
