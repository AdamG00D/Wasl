#!/usr/bin/env python3
"""يبني موقع جنبك (GitHub Pages) في site/ — عربي (الأساسي) وإنجليزي، بهوية الخيامية.

python3 tool/site.py   ← بعد أي تغيير في الكلام أو الصور. الموقع بيتنشر لوحده من .github/workflows/pages.yml.
"""
import html
import json
import shutil
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / 'site'
BASE = 'https://adamg00d.github.io/Ganbak/'
REPO = 'https://github.com/AdamG00D/Ganbak'
# التحميل المباشر لآخر إصدار (أسامي ثابتة بيعملها scripts/build_release.sh)
DOWNLOAD = REPO + '/releases/latest/download/Ganbak-android.apk'
DOWNLOAD_ALL = REPO + '/releases/latest/download/Ganbak-android-universal.apk'
RELEASES = REPO + '/releases/latest'
# الصيغ اللي الناس بتكتبها في جوجل (بالهمزة ومن غيرها، عامية وفصحى، عربي وإنجليزي) — بتدخل في meta keywords و JSON-LD
KEYWORDS = [
    'جنبك', 'جنبك شات', 'تطبيق جنبك', 'جنبك اوفلاين', 'جنبك بدون انترنت',
    'شات بدون إنترنت', 'شات بدون انترنت', 'شات بدون نت', 'شات من غير نت', 'شات من غير إنترنت', 'شات اوفلاين', 'شات أوفلاين',
    'دردشة بدون إنترنت', 'دردشة بدون انترنت', 'دردشة اوفلاين', 'دردشة بدون نت', 'محادثة بدون إنترنت', 'محادثة بدون انترنت',
    'برنامج شات بدون نت', 'برنامج دردشة بدون انترنت', 'تطبيق شات بدون انترنت', 'تطبيق مراسلة بدون إنترنت',
    'رسائل بدون إنترنت', 'رسايل من غير نت', 'شات بالبلوتوث', 'دردشة بالبلوتوث', 'محادثة عن طريق البلوتوث',
    'شات بالواي فاي', 'شات على الهوت سبوت', 'شات بدون شبكة', 'تواصل بدون إنترنت', 'التواصل وقت انقطاع الإنترنت',
    'شات مشفر', 'تطبيق مراسلة مشفر', 'شات للطوارئ', 'بديل بريدجفاي',
    'Ganbak', 'Ganbak chat', 'Ganbak offline chat', 'offline chat', 'offline chat app', 'offline messenger',
    'chat without internet', 'messaging without internet', 'no internet chat', 'Bluetooth chat', 'Bluetooth messenger',
    'Wi-Fi chat', 'hotspot chat', 'mesh messenger', 'mesh chat', 'off-grid messaging', 'emergency chat app',
    'encrypted offline chat', 'Bridgefy alternative', 'FireChat alternative', 'Arabic offline chat',
    # بيعمل إيه كمان من غير نت
    'إرسال صور بدون إنترنت', 'إرسال ملفات بدون نت', 'نقل ملفات بدون انترنت', 'رسائل صوتية بدون إنترنت', 'فويس من غير نت',
    'مكالمات بدون إنترنت', 'مكالمة فيديو بدون نت', 'جروبات بدون إنترنت', 'جروب شات بدون نت', 'رسالة استغاثة بدون إنترنت',
    'send photos without internet', 'file transfer without internet', 'voice messages offline', 'calls without internet',
    'offline group chat', 'SOS app without internet',
    # ألعاب من غير نت
    'ألعاب بدون إنترنت', 'ألعاب بدون انترنت', 'ألعاب بدون نت', 'العاب بدون نت', 'ألعاب أوفلاين', 'العاب اوفلاين',
    'ألعاب جماعية بدون نت', 'ألعاب جماعية أوفلاين', 'ألعاب بالبلوتوث', 'العاب بلوتوث', 'ألعاب للاتنين بدون نت',
    'ألعاب للرحلات', 'ألعاب للتجمعات', 'لعبة المافيا', 'لعبة المافيا بدون نت', 'لعبة مين الجاسوس', 'لعبة الجاسوس',
    'لعبة إكس أو', 'اكس او بالبلوتوث', 'لعبة حرب السفن', 'لعبة الذاكرة', 'لعبة أربعة في صف', 'حجر ورقة مقص',
    'لعبة المربعات والنقط', 'مسابقة أسئلة بدون نت', 'لعبة أسئلة جماعية',
    'offline games', 'games without internet', 'offline multiplayer games', 'Bluetooth multiplayer games',
    'local multiplayer games', 'party games offline', 'mafia game app', 'who is the spy game', 'spy word game',
    'tic tac toe Bluetooth', 'battleship game offline', 'connect four offline', 'memory game multiplayer',
    'rock paper scissors multiplayer', 'dots and boxes multiplayer', 'trivia quiz offline',
    # تستخدمه فين
    'شات في الرحلات', 'شات للتخييم', 'تواصل في الصحراء', 'شات في الصحرا', 'تواصل في الجبال', 'شات في الحفلات',
    'تواصل في الملاعب', 'تواصل في الزحمة', 'تواصل في الحج والعمرة', 'شات في الطيارة', 'وضع الطيران شات',
    'شات في المركب', 'تواصل في البحر', 'شات في المدرسة', 'شات في الجامعة', 'تواصل وقت انقطاع الكهرباء',
    'تواصل وقت قطع الإنترنت', 'تواصل في الزلازل والكوارث', 'تواصل في الطوارئ', 'مكان مفيهوش شبكة', 'من غير شبكة موبايل',
    'chat while camping', 'hiking chat app', 'festival chat app', 'concert messaging', 'stadium chat', 'Hajj communication app',
    'chat on airplane mode', 'cruise ship chat', 'classroom chat', 'blackout communication', 'internet shutdown app',
    'disaster communication app', 'earthquake emergency app', 'no signal messaging', 'no cell service chat',
]
SHOTS = ['chats', 'group-chat', 'nearby', 'games', 'game-mafia', 'guide']

T = {
    'ar': {
        'dir': 'rtl', 'path': '', 'other': 'en/', 'otherName': 'English',
        'title': 'جنبك: شات بدون إنترنت — دردشة أوفلاين مشفّرة بالبلوتوث والواي فاي لأندرويد (Ganbak)',
        'desc': 'جنبك (Ganbak) تطبيق شات ودردشة بدون إنترنت لأندرويد — شات أوفلاين من غير نت ولا سيرفر: الموبايلات القريبة بتكلم بعض بالبلوتوث والواي فاي وبتوصّل الرسايل لبعض كشبكة Mesh. محادثات خاصة مشفّرة، جروبات، ألعاب، وشبكة واي فاي من موبايلك. مجاني ومفتوح المصدر.',
        'hero': 'اتكلم مع اللي حواليك<br>من غير إنترنت',
        'heroSub': 'جنبك بيخلّي الموبايلات القريبة تكلم بعض بالبلوتوث والواي فاي، وتوصّل الرسايل لبعض كشبكة — من غير نت، ولا سيرفر، ولا حساب.',
        'download': 'حمّل جنبك لأندرويد', 'source': 'الكود على GitHub',
        'meta': 'مجاني • مفتوح المصدر (GPL-3.0) • أندرويد 7 أو أحدث',
        'old': 'موبايل قديم أو التثبيت فشل؟ حمّل النسخة الشاملة', 'all': 'كل النسخ',
        'featTitle': 'ليه جنبك؟',
        'feats': [
            ('📡', 'من غير إنترنت', 'بلوتوث، أو واي فاي / هوت سبوت، أو الاتنين مع بعض — وموبايلك يبقى كوبري بينهم.'),
            ('🕸️', 'الرسايل بتعدّي', 'كل موبايل بيوصّل للي بعده (لحد 6 موبايلات)، فالرسالة توصل أبعد بكتير من مدى موبايلك.'),
            ('🔒', 'شات خاص متشفّر', 'تشفير من طرف لطرف لوحده، واللي في النص مبيقدروش يقروا حاجة ولا يعرفوا مين بيكلم مين. ورمز أمان تتأكدوا بيه من بعض.'),
            ('✍️', 'محدش يتكلم باسمك', 'اسمك ورسايلك متوقّعة بمفتاحك، وجنبك بيحذّرك لو حد ظهر باسم واحد تعرفه بس مش هو.'),
            ('📶', 'شبكة جنبك', 'مفيش راوتر؟ موبايلك يعمل واي فاي لوحده واللي جنبك يدخلوه بضغطة أو بكود QR.'),
            ('⏳', 'الرسالة تستنى صاحبها', 'لو اللي بتكلمه مش موجود، الموبايلات اللي حواليك بتشيل رسالتك مقفولة لحد ما يظهر.'),
            ('🆘', 'استغاثة', 'اطلب مساعدة من كل اللي فاتحين جنبك حواليك بضغطة واحدة.'),
            ('🎮', 'ألعاب جوه الشات', 'إكس أو، حرب السفن، الذاكرة، مين الجاسوس؟، المسابقة، المافيا وغيرهم.'),
            ('👥', 'جروبات', 'عامة، أو بكلمة سر، أو بطلب انضمام، أو سرية بالدعوة بس — بصاحب ومشرفين.'),
        ],
        'seekTitle': 'بتدوّر على شات من غير نت؟',
        'seek': 'لو بتدوّر على شات بدون إنترنت، أو دردشة أوفلاين، أو تطبيق رسايل بالبلوتوث أو الواي فاي يشتغل من غير نت ولا شبكة — جنبك معمول لكده بالظبط.',
        'useTitle': 'تستخدمه فين؟',
        'uses': [
            ('🏕️', 'الرحلات والتخييم'), ('🏜️', 'الصحرا والجبال'), ('🎉', 'الحفلات والمهرجانات'), ('🏟️', 'الملاعب والماتشات'),
            ('🕋', 'الحج والعمرة والزحمة'), ('✈️', 'الطيارة (وضع الطيران)'), ('🚢', 'المراكب والبحر'), ('🎓', 'المدرسة والجامعة'),
            ('🏢', 'الشغل والمؤتمرات'), ('🔌', 'انقطاع الكهربا والنت'), ('🚨', 'الزلازل والطوارئ'), ('📵', 'أي مكان مفيهوش شبكة'),
        ],
        'gamesTitle': 'ألعاب من غير نت',
        'gamesSub': '9 ألعاب جماعية جوه الشات، بتتلعب بالبلوتوث أو الواي فاي مع اللي جنبك — من غير إنترنت.',
        'games': [
            ('إكس أو', '2'), ('أربعة في صف', '2'), ('حرب السفن', '2'), ('حجر ورقة مقص', '2'), ('المربعات والنقط', '2–4'),
            ('الذاكرة', '2–6'), ('مين الجاسوس؟', '3–12'), ('المسابقة', '2–15'), ('المافيا', '5–15'),
        ],
        'players': 'لاعبين',
        'shotsTitle': 'شكله',
        'shareTitle': 'صاحبك مفيهوش جنبك؟',
        'share': 'من الإعدادات ← "شارك جنبك": موبايلك يفتح شبكة، وصاحبك يصوّر كودين ويحمّل التطبيق من موبايلك على طول — من غير نت.',
        'faqTitle': 'أسئلة شائعة',
        'faq': [
            ('جنبك محتاج إنترنت؟', 'لأ. جنبك بيشتغل بالبلوتوث والواي فاي بين الموبايلات القريبة، من غير إنترنت ولا باقة ولا سيرفر.'),
            ('فيه تطبيق شات يشتغل بدون إنترنت؟', 'أيوه، جنبك: شات أوفلاين لأندرويد بيبعت الرسايل والصور والفويس بالبلوتوث أو الواي فاي أو الهوت سبوت، من غير نت خالص.'),
            ('فيه ألعاب بتشتغل من غير نت؟', 'أيوه، جنبك فيه 9 ألعاب جماعية من غير إنترنت: إكس أو، أربعة في صف، حرب السفن، حجر ورقة مقص، المربعات والنقط، الذاكرة، مين الجاسوس؟، المسابقة، والمافيا — بالبلوتوث أو الواي فاي.'),
            ('ينفع أبعت صور وفويس من غير نت؟', 'أيوه: صور وفيديو ورسايل صوتية وملفات، ومكالمات صوت وفيديو كمان على الواي فاي أو الهوت سبوت — كله من غير إنترنت.'),
            ('ينفع أستخدمه في الطيارة أو الصحرا أو الحج؟', 'أيوه، في أي مكان مفيهوش شبكة. في الطيارة شغّل البلوتوث أو الواي فاي وانت على وضع الطيران (لو مسموح في الرحلة).'),
            ('ينفع أدردش بالبلوتوث بس؟', 'أيوه. اختار بلوتوث في أول شاشة والموبايلات القريبة هتلاقي بعض لوحدها، ولو فيه واي فاي أو هوت سبوت جنبك يستخدم الاتنين مع بعض.'),
            ('إزاي أكلم حد بعيد عني؟', 'الرسايل بتعدّي على موبايلات تانية فاتحة جنبك (لحد 6). وكمان لو هو مش موجود دلوقتي، رسالتك بتستنى وتوصله أول ما يظهر.'),
            ('الشات متشفّر؟', 'الشات الخاص متشفّر من طرف لطرف تلقائياً. التفاصيل والحدود المعروفة مكتوبة بصراحة في صفحة الأمان على GitHub.'),
            ('جنبك مجاني؟', 'أيوه، مجاني ومفتوح المصدر (GPL-3.0)، مفيهوش إعلانات ولا تحليلات.'),
            ('بيشتغل على أنهي موبايلات؟', 'أندرويد 7 أو أحدث. شبكة جنبك محتاجة أندرويد 8+، والدخول منها من جوه التطبيق أندرويد 10+.'),
        ],
        'foot': 'جنبك — مفتوح المصدر تحت رخصة GPL-3.0',
        'shotAlt': {'chats': 'المحادثات', 'group-chat': 'شات جروب', 'nearby': 'القريبين', 'games': 'الألعاب', 'game-mafia': 'المافيا', 'guide': 'دليل جنبك'},
    },
    'en': {
        'dir': 'ltr', 'path': 'en/', 'other': '../', 'otherName': 'العربية',
        'title': 'Ganbak: Offline Chat — chat without internet over Bluetooth and Wi-Fi for Android (جنبك)',
        'desc': 'Ganbak (جنبك) is an offline chat and messenger app for Android: chat without internet — phones nearby talk over Bluetooth and Wi-Fi and relay messages as a mesh, with no internet and no server. End-to-end encrypted private chats, groups, games and your own Wi-Fi network. Free and open source.',
        'hero': 'Talk to people around you<br>with no internet',
        'heroSub': 'Ganbak lets nearby phones talk over Bluetooth and Wi-Fi and relay messages for each other as a mesh — no internet, no server, no account.',
        'download': 'Get Ganbak for Android', 'source': 'Source on GitHub',
        'meta': 'Free • Open source (GPL-3.0) • Android 7+',
        'old': 'Older phone or install failed? Get the universal build', 'all': 'All builds',
        'featTitle': 'Why Ganbak?',
        'feats': [
            ('📡', 'No internet needed', 'Bluetooth, Wi-Fi / hotspot, or both at once — your phone becomes a bridge between them.'),
            ('🕸️', 'Messages hop', 'Every phone relays to the next (up to 6), so a message reaches far beyond your own range.'),
            ('🔒', 'Encrypted private chats', 'End-to-end encryption by default; relays can’t read anything or tell who talks to whom. Safety codes to verify each other.'),
            ('✍️', 'Nobody speaks for you', 'Your name and messages are signed with your key, and Ganbak warns you when someone shows up with a name you know but isn’t them.'),
            ('📶', 'Ganbak network', 'No router? Your phone makes its own Wi-Fi and people nearby join with one tap or a QR code.'),
            ('⏳', 'Messages wait', 'If the person isn’t around, phones nearby carry your sealed message until they show up.'),
            ('🆘', 'SOS', 'Ask everyone running Ganbak around you for help with one tap.'),
            ('🎮', 'Games in chats', 'Tic-tac-toe, battleships, memory, who’s the spy?, quiz, mafia and more.'),
            ('👥', 'Groups', 'Open, password, join-request or invite-only secret groups, with an owner and admins.'),
        ],
        'seekTitle': 'Looking for chat without internet?',
        'seek': 'If you’re looking for an offline chat app, an offline messenger, or a Bluetooth or Wi-Fi chat that works with no internet and no cell signal — that’s exactly what Ganbak is for.',
        'useTitle': 'Where to use it',
        'uses': [
            ('🏕️', 'Trips and camping'), ('🏜️', 'Deserts and mountains'), ('🎉', 'Festivals and concerts'), ('🏟️', 'Stadiums and matches'),
            ('🕋', 'Hajj, Umrah and crowds'), ('✈️', 'Flights (airplane mode)'), ('🚢', 'Boats and cruises'), ('🎓', 'Schools and campuses'),
            ('🏢', 'Work and conferences'), ('🔌', 'Power and internet cuts'), ('🚨', 'Earthquakes and emergencies'), ('📵', 'Anywhere with no signal'),
        ],
        'gamesTitle': 'Games with no internet',
        'gamesSub': '9 multiplayer games inside chats, played over Bluetooth or Wi-Fi with the people around you — no internet.',
        'games': [
            ('Tic-tac-toe', '2'), ('Four in a row', '2'), ('Battleships', '2'), ('Rock paper scissors', '2'), ('Dots and boxes', '2–4'),
            ('Memory', '2–6'), ('Who’s the spy?', '3–12'), ('Quiz', '2–15'), ('Mafia', '5–15'),
        ],
        'players': 'players',
        'shotsTitle': 'What it looks like',
        'shareTitle': 'Your friend doesn’t have it?',
        'share': 'Settings → “Share Ganbak”: your phone opens a network, your friend scans two codes and downloads the app straight from your phone — no internet.',
        'faqTitle': 'FAQ',
        'faq': [
            ('Does Ganbak need the internet?', 'No. It works over Bluetooth and Wi-Fi between nearby phones, with no internet, no data plan and no server.'),
            ('Is there a chat app that works without internet?', 'Yes — Ganbak is an offline chat app for Android that sends messages, photos and voice notes over Bluetooth, Wi-Fi or a hotspot, with no internet at all.'),
            ('Are there games that work without internet?', 'Yes — Ganbak has 9 offline multiplayer games: tic-tac-toe, four in a row, battleships, rock paper scissors, dots and boxes, memory, who’s the spy?, quiz and mafia — over Bluetooth or Wi-Fi.'),
            ('Can I send photos and voice notes without internet?', 'Yes: photos, videos, voice notes and files, plus voice and video calls over Wi-Fi or a hotspot — all with no internet.'),
            ('Can I use it on a plane, in the desert or at Hajj?', 'Yes, anywhere with no signal. On a plane, turn Bluetooth or Wi-Fi on in airplane mode (if the flight allows it).'),
            ('Can I chat over Bluetooth only?', 'Yes. Pick Bluetooth on the first screen and nearby phones find each other; with Wi-Fi or a hotspot around, Ganbak can use both at once.'),
            ('How do I reach someone far away?', 'Messages hop through other phones running Ganbak (up to 6). And if they’re not around right now, your message waits and reaches them when they show up.'),
            ('Is it encrypted?', 'Private chats are end-to-end encrypted automatically. Details and known limits are written plainly in the security page on GitHub.'),
            ('Is Ganbak free?', 'Yes — free and open source (GPL-3.0), with no ads and no analytics.'),
            ('Which phones?', 'Android 7 or newer. Starting a Ganbak network needs Android 8+, joining one from inside the app Android 10+.'),
        ],
        'foot': 'Ganbak — open source under GPL-3.0',
        'shotAlt': {'chats': 'Chats', 'group-chat': 'Group chat', 'nearby': 'Nearby', 'games': 'Games', 'game-mafia': 'Mafia', 'guide': 'Ganbak guide'},
    },
}

LOGO = ('<svg viewBox="0 0 1024 1024" width="{s}" height="{s}" aria-hidden="true">'
        '<rect x="8" y="8" width="1008" height="1008" rx="230" fill="#262B55" stroke="#F4B400" stroke-opacity=".5" stroke-width="16"/>'
        '<rect x="214" y="234" width="596" height="420" rx="140" fill="none" stroke="#F4B400" stroke-width="14" stroke-dasharray="44 30" opacity=".55"/>'
        '<path d="M352 508 L512 372 L672 508" fill="none" stroke="#F4B400" stroke-width="34" stroke-linecap="round"/>'
        '<circle cx="352" cy="508" r="54" fill="#F4B400"/><circle cx="512" cy="372" r="54" fill="#F4B400"/>'
        '<circle cx="672" cy="508" r="54" fill="#F4B400"/><path d="M420 654 L380 760 L500 654" fill="#F4B400" opacity=".85"/></svg>')


def page(lang: str) -> str:
    t = T[lang]
    e = html.escape
    up = '../' if t['path'] else ''
    url = BASE + t['path']
    ld = {
        '@context': 'https://schema.org', '@type': 'SoftwareApplication',
        'name': 'Ganbak', 'alternateName': ['جنبك', 'جنبك شات', 'Ganbak Offline Chat', 'جنبك: شات بدون إنترنت'],
        'keywords': ', '.join(KEYWORDS), 'operatingSystem': 'Android 7.0+',
        'applicationCategory': 'CommunicationApplication', 'description': t['desc'],
        'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'USD'},
        'downloadUrl': DOWNLOAD, 'installUrl': DOWNLOAD, 'license': 'https://www.gnu.org/licenses/gpl-3.0.html',
        'url': url, 'image': BASE + 'img/banner.en.png', 'codeRepository': REPO, 'inLanguage': ['ar', 'en'],
    }
    faq_ld = {
        '@context': 'https://schema.org', '@type': 'FAQPage',
        'mainEntity': [{'@type': 'Question', 'name': q, 'acceptedAnswer': {'@type': 'Answer', 'text': a}} for q, a in t['faq']],
    }
    feats = '\n'.join(
        f'<div class="feat"><div class="ic">{i}</div><h3>{e(h)}</h3><p>{e(p)}</p></div>' for i, h, p in t['feats'])
    shots = '\n'.join(
        f'<img src="{up}img/{lang}/{s}.png" alt="{e(t["shotAlt"][s])}" width="270" height="570" loading="lazy">' for s in SHOTS)
    games = '\n'.join(
        f'<div class="chip"><b>{e(n)}</b><span>{e(c)} {e(t["players"])}</span></div>' for n, c in t['games'])
    uses = '\n'.join(f'<div class="use"><span>{i}</span>{e(x)}</div>' for i, x in t['uses'])
    faq = '\n'.join(f'<details><summary>{e(q)}</summary><p>{e(a)}</p></details>' for q, a in t['faq'])
    dl_icon = ('<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="currentColor" d="M12 3a1 1 0 0 1 1 1v9.6'
               'l3.3-3.3a1 1 0 1 1 1.4 1.4l-5 5a1 1 0 0 1-1.4 0l-5-5a1 1 0 1 1 1.4-1.4l3.3 3.3V4a1 1 0 0 1 1-1zM5 19h14a1 1 0 1 1 0 2H5a1 1 0 1 1 0-2z"/></svg>')
    return f'''<!doctype html>
<html lang="{lang}" dir="{t['dir']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(t['title'])}</title>
<meta name="description" content="{e(t['desc'])}">
<meta name="keywords" content="{e(', '.join(KEYWORDS))}">
<meta name="robots" content="index, follow, max-image-preview:large">
<link rel="canonical" href="{url}">
<link rel="alternate" hreflang="ar" href="{BASE}">
<link rel="alternate" hreflang="en" href="{BASE}en/">
<link rel="alternate" hreflang="x-default" href="{BASE}">
<meta property="og:type" content="website">
<meta property="og:title" content="{e(t['title'])}">
<meta property="og:description" content="{e(t['desc'])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{BASE}img/banner.{lang}.png">
<meta property="og:locale" content="{'ar_EG' if lang == 'ar' else 'en_US'}">
<meta property="og:site_name" content="{'جنبك' if lang == 'ar' else 'Ganbak'}">
<meta property="og:image:alt" content="{e(t['title'])}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{e(t['title'])}">
<meta name="twitter:description" content="{e(t['desc'])}">
<meta name="twitter:image" content="{BASE}img/banner.{lang}.png">
<meta name="theme-color" content="#1B1F3B">
<link rel="icon" href="{up}img/icon.png" type="image/png">
<link rel="apple-touch-icon" href="{up}img/icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{up}style.css">
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
<script type="application/ld+json">{json.dumps(faq_ld, ensure_ascii=False)}</script>
</head>
<body>
<header class="hero">
<nav><a class="brand" href="{up or './'}">{LOGO.format(s=36)}<span>{'جنبك' if lang == 'ar' else 'Ganbak'}</span></a>
<a class="lang" href="{t['other']}" hreflang="{'en' if lang == 'ar' else 'ar'}">{t['otherName']}</a></nav>
<div class="hero-in">
{LOGO.format(s=96)}
<h1>{t['hero']}</h1>
<p>{e(t['heroSub'])}</p>
<div class="cta"><a class="btn" href="{DOWNLOAD}">{dl_icon}{e(t['download'])}</a>
<a class="btn ghost" href="{REPO}">{e(t['source'])}</a></div>
<p class="meta">{e(t['meta'])}</p>
<p class="meta"><a href="{DOWNLOAD_ALL}">{e(t['old'])}</a> • <a href="{RELEASES}">{e(t['all'])}</a></p>
</div>
</header>
<main>
<section><h2>{e(t['featTitle'])}</h2><div class="grid">
{feats}
</div></section>
<section><h2>{e(t['gamesTitle'])}</h2><p class="sub">{e(t['gamesSub'])}</p><div class="chips">
{games}
</div></section>
<section><h2>{e(t['useTitle'])}</h2><div class="uses">
{uses}
</div></section>
<section class="band"><h2>{e(t['seekTitle'])}</h2><p>{e(t['seek'])}</p></section>
<section><h2>{e(t['shotsTitle'])}</h2><div class="shots">
{shots}
</div></section>
<section class="band"><h2>{e(t['shareTitle'])}</h2><p>{e(t['share'])}</p></section>
<section><h2>{e(t['faqTitle'])}</h2><div class="faq">
{faq}
</div></section>
</main>
<footer><p>{e(t['foot'])} • <a href="{REPO}">GitHub</a> • <a href="{REPO}/blob/main/SECURITY{'.ar' if lang == 'ar' else ''}.md">{'الأمان' if lang == 'ar' else 'Security'}</a></p></footer>
</body>
</html>
'''


CSS = '''
:root{--ink:#1B1F3B;--ink2:#262B55;--saffron:#F4B400;--saffron-ink:#8F5E00;--bg:#FBF6EC;--card:#fff;--text:#1B1F3B;--muted:#5B5F7A;--line:#EADFC8;--teal:#0F8B8D}
@media (prefers-color-scheme:dark){:root{--bg:#0F1226;--card:#1A1E3A;--text:#F3EEE2;--muted:#A9ACC4;--line:#2C3157;--saffron-ink:#F6BE2C}}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--text);font-family:"IBM Plex Sans Arabic",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.7}
a{color:inherit}
.hero{background:var(--ink) url("img/pattern.svg");color:#fff;padding:0 16px 56px;border-bottom:4px dashed rgba(244,180,0,.5)}
nav{max-width:1040px;margin:0 auto;display:flex;align-items:center;justify-content:space-between;padding:14px 0}
.brand{display:flex;align-items:center;gap:10px;text-decoration:none;font-weight:700;font-size:20px}
.lang{color:var(--saffron);font-weight:700;text-decoration:none;border:1px solid rgba(244,180,0,.5);padding:4px 12px;border-radius:999px}
.hero-in{max-width:760px;margin:20px auto 0;text-align:center}
.hero h1{font-size:clamp(30px,6vw,48px);line-height:1.3;margin:16px 0 12px}
.hero p{color:#D8D9E6;font-size:18px;margin:0 auto;max-width:620px}
.cta{display:flex;flex-wrap:wrap;gap:12px;justify-content:center;margin-top:26px}
.btn{display:inline-flex;align-items:center;gap:10px;background:var(--saffron);color:var(--ink);font-weight:700;font-size:18px;padding:14px 22px;border-radius:16px;text-decoration:none}
.btn.ghost{background:transparent;color:#fff;border:1.5px solid rgba(255,255,255,.4)}
.hero .meta{font-size:14px;color:#B9BBD0;margin-top:14px}
.hero .meta a{color:#F6D27A}
main{max-width:1040px;margin:0 auto;padding:0 16px}
section{padding:48px 0 8px}
h2{font-size:28px;margin:0 0 18px;color:var(--saffron-ink);text-align:center}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}
.feat{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:18px}
.feat .ic{font-size:28px}
.feat h3{margin:6px 0 4px;font-size:18px}
.feat p{margin:0;color:var(--muted);font-size:15px}
.band{background:var(--card);border:1px dashed var(--line);border-radius:22px;padding:26px 20px;margin-top:40px;text-align:center}
.band p{max-width:680px;margin:0 auto;font-size:17px}
.sub{text-align:center;color:var(--muted);max-width:680px;margin:-8px auto 18px;font-size:17px}
.chips{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;max-width:820px;margin:0 auto}
@media (max-width:600px){.chips{grid-template-columns:repeat(2,1fr)}.chip:last-child:nth-child(odd){grid-column:1/-1}}
.chip{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:12px 14px;display:flex;flex-direction:column}
.chip b{font-size:16px}
.chip span{color:var(--muted);font-size:13px}
.uses{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}
@media (max-width:900px){.uses{grid-template-columns:repeat(2,1fr)}}
.use{background:var(--card);border:1px dashed var(--line);border-radius:16px;padding:12px 14px;display:flex;align-items:center;gap:10px;font-weight:600}
.use span{font-size:22px}
.shots{display:flex;gap:14px;overflow-x:auto;padding:4px 2px 14px;scroll-snap-type:x mandatory}
.shots img{flex:0 0 auto;width:210px;height:auto;border-radius:22px;border:1px solid var(--line);scroll-snap-align:center;background:var(--card)}
.faq{max-width:760px;margin:0 auto}
details{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:14px 18px;margin-bottom:10px}
summary{font-weight:700;cursor:pointer;font-size:17px}
details p{color:var(--muted);margin:10px 0 0}
footer{text-align:center;color:var(--muted);padding:40px 16px;font-size:14px}
footer a{color:var(--saffron-ink);font-weight:700}
'''

PATTERN = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
           '<g fill="none" stroke="#F4B400" stroke-opacity=".14" stroke-width="2"><rect x="17" y="17" width="30" height="30"/>'
           '<rect x="17" y="17" width="30" height="30" transform="rotate(45 32 32)"/></g>'
           '<circle cx="32" cy="32" r="3" fill="#F4B400" fill-opacity=".14"/></svg>')


def main() -> None:
    if SITE.exists():
        shutil.rmtree(SITE)
    (SITE / 'en').mkdir(parents=True)
    (SITE / 'img').mkdir()
    for lang, src in (('ar', ROOT / 'docs/images/screenshots'), ('en', ROOT / 'docs/images/screenshots/en')):
        (SITE / 'img' / lang).mkdir()
        for s in SHOTS:
            shutil.copy(src / f'{s}.png', SITE / 'img' / lang / f'{s}.png')
    for lang in ('ar', 'en'):
        shutil.copy(ROOT / f'docs/images/banner.{lang}.png', SITE / 'img' / f'banner.{lang}.png')
    shutil.copy(ROOT / 'tool/icon_preview.png', SITE / 'img/icon.png')
    (SITE / 'img/pattern.svg').write_text(PATTERN)
    (SITE / 'style.css').write_text(CSS.strip() + '\n')
    (SITE / 'index.html').write_text(page('ar'))
    (SITE / 'en/index.html').write_text(page('en'))
    (SITE / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {BASE}sitemap.xml\n')
    (SITE / 'sitemap.xml').write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
        + ''.join(
            f'  <url><loc>{BASE}{p}</loc><lastmod>{date.today().isoformat()}</lastmod>'
            f'<xhtml:link rel="alternate" hreflang="ar" href="{BASE}"/>'
            f'<xhtml:link rel="alternate" hreflang="en" href="{BASE}en/"/></url>\n' for p in ('', 'en/'))
        + '</urlset>\n')
    (SITE / '.nojekyll').write_text('')
    # تأكيد ملكية الموقع لـ Google Search Console (الملف اللي جوجل اداه لصاحب المشروع)
    (SITE / 'google6da38e735cb6412d.html').write_text('google-site-verification: google6da38e735cb6412d.html')
    print('site/ built')


if __name__ == '__main__':
    main()
