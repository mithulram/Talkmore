import Image from 'next/image';

const githubUrl = 'https://github.com/mithulram/Talkmore';
const issuesUrl = `${githubUrl}/issues/new/choose`;
const assetBasePath = process.env.GITHUB_PAGES === 'true' ? '/Talkmore' : '';
const talkmoreIcon = `${assetBasePath}/talkmore-icon.png`;

const features = [
  ['01', 'Hold fn. Say it. Done.', 'One key is the entire interface. Talkmore listens while fn is held, catches the final word, and inserts when you release.', 'featureViolet'],
  ['02', 'Your audio stays yours.', 'Apple Speech runs on your Mac. There is no Talkmore cloud, account, analytics pipeline, or audio upload.', 'featureCyan'],
  ['03', 'Made for where you type.', 'Accessibility-first insertion with a safe paste fallback works across native apps, browsers, Electron editors, and terminals.', 'featurePeach'],
];

const modes = [
  ['Automatic', 'Chooses the right style for the app under your cursor.'],
  ['Everyday', 'Natural messages with clean punctuation and fewer fillers.'],
  ['Concise', 'Tightens a thought without changing what you meant.'],
  ['Email', 'Understands subject lines, paragraphs, greetings, and sign-offs.'],
  ['Developer', 'Preserves technical language, symbols, casing, and filenames.'],
  ['Verbatim', 'Keeps the recognized words exactly as spoken.'],
];

const roadmap = [
  ['Shipping now', 'Fast local dictation', 'On-device recognition, six writing styles, dictionary, history, and safe cross-app insertion.'],
  ['Next', 'A signed Mac download', 'Developer ID signing, notarization, automatic updates, and a one-click installer.'],
  ['Exploring', 'Smarter local corrections', 'Memory-aware language models that load only when needed, without slowing first insertion.'],
  ['Later', 'Languages + benchmarks', 'A public compatibility and latency suite across accents, languages, and popular Mac apps.'],
];

export default function Home() {
  return (
    <main>
      <nav className="nav shell" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="Talkmore home">
          <Image src={talkmoreIcon} alt="" width={38} height={38} priority />
          <span>Talkmore</span>
        </a>
        <div className="navLinks">
          <a href="#features">Features</a>
          <a href="#install">Install</a>
          <a href="#roadmap">Roadmap</a>
          <a className="navGithub" href={githubUrl}>GitHub <span>↗</span></a>
        </div>
      </nav>

      <section className="hero shell" id="top">
        <div className="heroCopy">
          <p className="eyebrow"><span /> Private. Local. Fast.</p>
          <h1>Your voice,<br /><em>already written.</em></h1>
          <p className="lede">Hold fn, speak naturally, and release. Talkmore turns your voice into clean text in the app beneath your cursor—without an account, a server, or cloud audio.</p>
          <div className="actions">
            <a className="button primary" href="#install">Build for your Mac</a>
            <a className="button secondary" href={githubUrl}>Steal the code, legally <span>↗</span></a>
          </div>
          <p className="fineprint">Free and open source · Apple silicon · macOS 26+</p>
        </div>

        <div className="productStage" aria-label="Talkmore menu bar app preview">
          <div className="glow" />
          <div className="menuMockup">
            <div className="mockHeader">
              <Image src={talkmoreIcon} alt="Talkmore icon" width={48} height={48} />
              <div><strong>Talkmore</strong><small><i /> Ready</small></div>
              <b>LOCAL</b>
            </div>
            <div className="talkRow"><span className="wave">≋</span><strong>Hold to talk</strong><kbd>fn</kbd></div>
            <div className="styleRow"><span>✦</span><strong>Writing style</strong><button type="button">Automatic⌄</button></div>
            <p>Ready · mic yes, speech yes, accessibility yes</p>
            <footer><span>⚙ Settings</span><span>Quit</span></footer>
          </div>
          <div className="latencyPill"><span>●</span> 0.40s warm insertion</div>
          <div className="voiceOrb" aria-hidden="true"><i /><i /><i /><i /><i /></div>
        </div>
      </section>

      <section className="proofStrip" aria-label="Talkmore at a glance">
        <div className="shell proofGrid">
          <div><strong>~0.40s</strong><span>warm release-to-insert</span></div>
          <div><strong>100%</strong><span>on-device recognition</span></div>
          <div><strong>6</strong><span>purpose-built styles</span></div>
          <div><strong>0</strong><span>accounts or subscriptions</span></div>
        </div>
      </section>

      <section className="section shell" id="features">
        <div className="sectionIntro">
          <p className="kicker">Speak at the speed of thought</p>
          <h2>Dictation that gets<br />out of your way.</h2>
          <p>Talkmore is intentionally small: one shortcut, one local pipeline, and text exactly where you need it.</p>
        </div>
        <div className="featureGrid">
          {features.map(([number, title, copy, className]) => (
            <article className={`featureCard ${className}`} key={number}>
              <span className="featureNumber">{number}</span>
              <div className="featureGlyph" aria-hidden="true"><i /><i /><i /></div>
              <h3>{title}</h3><p>{copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="contextSection">
        <div className="shell contextGrid">
          <div className="contextCopy">
            <p className="kicker">Context without the cloud</p>
            <h2>It knows how you&apos;re writing.</h2>
            <p>Automatic mode notices whether you are in Mail, Cursor, Codex, Xcode, a browser, or a terminal and selects the right deterministic cleanup. Optional Apple Intelligence can polish the result after the fast first insertion.</p>
            <a className="textLink" href={`${githubUrl}/blob/main/Docs/PRODUCT_GUIDE.md`}>Read the product guide <span>→</span></a>
          </div>
          <div className="modePanel" aria-label="Talkmore writing modes">
            {modes.map(([title, copy], index) => (
              <div className={index === 0 ? 'activeMode' : ''} key={title}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <section><strong>{title}</strong><small>{copy}</small></section>
                {index === 0 && <b>DEFAULT</b>}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section shell privacySection">
        <div className="privacyVisual" aria-hidden="true">
          <div className="macChip"><span></span><strong>On your Mac</strong><small>audio never leaves</small></div>
          <div className="orbit orbitOne" /><div className="orbit orbitTwo" />
          <span className="privateTag privateOne">Speech</span><span className="privateTag privateTwo">Dictionary</span><span className="privateTag privateThree">History</span>
        </div>
        <div className="privacyCopy">
          <p className="kicker">Private by architecture</p>
          <h2>No cloud to trust.<br />No data to leak.</h2>
          <p>Microphone capture, Apple Speech recognition, cleanup, dictionary replacements, and history all stay on your Mac. The source is open so the privacy promise is inspectable.</p>
          <ul>
            <li><span>✓</span> No backend or network transcription</li>
            <li><span>✓</span> No account, tracking, or analytics SDK</li>
            <li><span>✓</span> Local history can be disabled or erased</li>
          </ul>
        </div>
      </section>

      <section className="installSection" id="install">
        <div className="shell installGrid">
          <div className="installCopy">
            <p className="kicker">Install the open beta</p>
            <h2>Four minutes.<br />One local build.</h2>
            <p>Talkmore is currently distributed from source while signed and notarized releases are being prepared. You always know exactly what is running on your Mac.</p>
            <div className="requirements"><span>macOS 26+</span><span>Apple silicon</span><span>Xcode 26+</span></div>
            <a className="button primary" href={`${githubUrl}/blob/main/Docs/INSTALLATION.md`}>Open the full install guide</a>
          </div>
          <div className="terminalCard">
            <header><i /><i /><i /><span>Terminal — zsh</span></header>
            <pre><code><span className="comment"># 1. Get Talkmore</span>{'\n'}git clone https://github.com/mithulram/Talkmore.git{'\n'}cd Talkmore{'\n\n'}<span className="comment"># 2. Open the native Mac project</span>{'\n'}open Talkmore.xcodeproj</code></pre>
            <footer><span>3. Press Run in Xcode</span><span>4. Grant the four macOS permissions</span></footer>
          </div>
        </div>
      </section>

      <section className="section shell roadmapSection" id="roadmap">
        <div className="sectionIntro roadmapIntro">
          <p className="kicker">Built in public</p>
          <h2>The path to an<br />exceptional Mac app.</h2>
          <p>No invented promises. Here is what works today and what the project will earn next.</p>
        </div>
        <div className="roadmapList">
          {roadmap.map(([status, title, copy], index) => (
            <article key={title}><span className={`status status${index}`}>{status}</span><h3>{title}</h3><p>{copy}</p><b>{String(index + 1).padStart(2, '0')}</b></article>
          ))}
        </div>
        <div className="roadmapAction"><p>Found a rough edge or have an idea that would make Talkmore meaningfully better?</p><a className="button secondary" href={issuesUrl}>Open a GitHub issue <span>↗</span></a></div>
      </section>

      <section className="faqSection">
        <div className="shell faqGrid">
          <div><p className="kicker">Good questions</p><h2>Before you<br />hold fn.</h2></div>
          <div className="faqs">
            <details open><summary>Is Talkmore really local?</summary><p>Yes. Audio is transcribed with Apple&apos;s on-device Speech framework. Talkmore has no server, account system, analytics, or network transcription service.</p></details>
            <details><summary>Why do I build it with Xcode?</summary><p>The open beta is not Developer ID signed or notarized yet. Building from source is the honest, safe installation path until a one-click release is ready.</p></details>
            <details><summary>Does Apple Intelligence slow down dictation?</summary><p>No. The first text insertion never waits for rewriting. Optional on-device polish happens afterward and is applied only when it is safe.</p></details>
            <details><summary>Which permissions are required?</summary><p>Microphone and Speech Recognition power dictation. Accessibility inserts text. Input Monitoring lets Talkmore detect the fn key globally.</p></details>
            <details><summary>Can I use it in Cursor, Codex, or a terminal?</summary><p>Yes. Developer mode is designed for coding apps and terminals, with safe paste fallback where direct accessibility insertion is unavailable.</p></details>
          </div>
        </div>
      </section>

      <section className="finalCta shell">
        <Image src={talkmoreIcon} alt="Talkmore icon" width={74} height={74} />
        <p className="kicker">Open source by default</p>
        <h2>Your next thought<br /><em>doesn&apos;t need the cloud.</em></h2>
        <div className="actions"><a className="button primary" href="#install">Build Talkmore</a><a className="button secondary" href={githubUrl}>Explore the source <span>↗</span></a></div>
      </section>

      <footer className="siteFooter shell">
        <a className="brand" href="#top"><Image src={talkmoreIcon} alt="" width={30} height={30} /><span>Talkmore</span></a>
        <p>Local push-to-talk dictation for Mac.</p>
        <div><a href={`${githubUrl}/blob/main/LICENSE`}>MIT License</a><a href={`${githubUrl}/blob/main/SECURITY.md`}>Security</a><a href={githubUrl}>GitHub</a></div>
      </footer>
    </main>
  );
}
