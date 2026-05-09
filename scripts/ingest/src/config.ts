// 情報収集ソース一覧
// 規約NG: サウナイキタイ・X(Twitter)・食べログ・TikTok は含めない

export const FEDIVERSE_HASHTAGS = [
  'サウナ', '温泉', '銭湯', 'サ活', 'ととのう', 'ロウリュ', '個室サウナ', '温泉旅館',
];

export const MISSKEY_INSTANCES = [
  'misskey.io',
];

export const MASTODON_INSTANCES = [
  'mstdn.jp',
  'fedibird.com',
  'pawoo.net',
];

// YouTubeチャンネル（RSS: APIキー不要・直近15動画）
// channel_id は "view-source:" でページを開いて "channelId":"UC..." を確認
export const YOUTUBE_CHANNELS: Array<{ id: string; name: string }> = [
  { id: 'UCqvaqxGePQWvXMAi9-524uA', name: '温泉女子会公式' },
  { id: 'UCBPQZSaHkcnXHQlnOMjDyiA', name: '&sauna アンドサウナ' },
  { id: 'UCqcoat4Wur2_9SMKg6PfpYg', name: 'マグ万平ののちほどサウナで' },
  { id: 'UCKOMCEkKNKPK_HpBotJFK-w', name: 'ニフティ温泉' },
  { id: 'UClAtpDytL1hmOUeiJaNrHlQ', name: '道後温泉公式' },
  { id: 'UCzQsMS_WO1NFhgJZkZ5-GXQ', name: 'miiの休み時間' },
  { id: 'UCLj5RBcMdm2F2GQ0o7Pdxbg', name: '田中なつき／なっちゃん' },
  { id: 'UCmJuf67BYauQMkJL_UH4agw', name: '向井長田のくるま温泉ちゃんねる' },
  { id: 'UCqs82jyw-b84QydpQ90IpAw', name: 'まゆ温泉&旅打ちチャンネル' },
  { id: 'UCMNlamFhTZK6qbgtQnoXkfQ', name: '温泉むすめ公式' },
  { id: 'UCfMWHJahlHBitmpQ0D3L7Yg', name: '松野井雅サウナ' },
  { id: 'UCS2uST8mBJ2pAof78GXm8lQ', name: 'ぽっちゃり女子の秘湯温泉旅' },
  { id: 'UCi3fNfsLg3cSH7_j-IpnETQ', name: 'おもろい温泉' },
];

// ブログ・メディア RSS（APIキー不要・無料・無制限）
export const RSS_SOURCES: Array<{ url: string; name: string }> = [
  // はてなブログ
  { url: 'https://yukatsu.hatenablog.com/rss',          name: '湯活のススメ' },
  // WordPress個人ブログ
  { url: 'https://yamaonsen.com/feed/',                  name: '山と温泉のきろく' },
  { url: 'https://onsenzanmaiblog.com/feed/',            name: 'KOUのふわふわ温泉' },
  // { url: 'https://hikyou.jp/feed/',                     name: '秘境温泉 神秘の湯' },      // 404 (2026-04)
  // { url: 'https://sauna.color-hiyoko.com/feed/',        name: '東京サウナ日記' },            // 404 (2026-04)
  { url: 'https://saunamizuburo.com/feed/',              name: 'Sauna&Waterbath' },
  { url: 'https://saturday-saunalover.com/feed/',       name: 'かいたくんのサウナブログ' },
  // note（RSS提供あり）
  { url: 'https://note.com/tsukiyamamomo/rss',          name: '月山もも（note）' },
  { url: 'https://note.com/yukatsu/rss',                name: '湯活のススメ（note）' },
  { url: 'https://note.com/sauna_freaks/rss',           name: 'サウナフリークス（note）' },
  { url: 'https://note.com/hamigakinote/rss',           name: 'はせがわ（note）' },
  // 商業メディア（動作確認済み）
  {
    url: 'https://travel.watch.impress.co.jp/data/rss/1.0/trw/feed.rdf',
    name: 'トラベルWatch',
  },
];

// リクエスト間隔（レート制限対策）
export const FETCH_DELAY_MS = 1000;

// User-Agent（Librahack判例に倣い連絡先を明示）
export const USER_AGENT = 'YuMap-Ingest/1.0 (+https://github.com/yumap)';
