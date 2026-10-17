import Image from 'next/image';
import { NotifyButton } from './NotifyDialog';

const features = [
  [
    'Offline route guidance',
    'Download trail geometry and stage-point context before leaving mobile coverage.',
  ],
  [
    'Flexible trip planning',
    'Choose your start and finish, compare walking days and shape a route around your pace.',
  ],
  [
    'Elevation at a glance',
    'Understand climbs, descents and the terrain ahead before committing to the next section.',
  ],
  [
    'Trail-side stays',
    'Find practical accommodation near a stage point and contact hosts directly.',
  ],
];

export function AppDownload({
  screenshots = false,
  id = 'app',
}: {
  screenshots?: boolean;
  id?: string;
}) {
  const appStore = process.env.NEXT_PUBLIC_APP_STORE_URL;
  const playStore = process.env.NEXT_PUBLIC_PLAY_STORE_URL;
  return (
    <section
      className={
        screenshots
          ? 'hiker-showcase screenshot-app-showcase'
          : 'app-download-section compact-app-download'
      }
      id={id}
      aria-labelledby={`${id}-title`}
    >
      <div className={`section-shell${screenshots ? ' hiker-layout' : ''}`}>
        {screenshots && (
          <>
            <div className="hiker-heading">
              <h2 className="section-title">
                {id === 'hikers'
                  ? 'For Hikers'
                  : 'Take Cyprus-E4 in your pocket'}
              </h2>
            </div>
            <div className="app-gallery-wrap">
              <div
                className="app-gallery"
                aria-label="Screenshots from the EuroTrex iPhone app"
                role="region"
                tabIndex={0}
              >
                {[
                  [
                    'planner',
                    'Shape your trip',
                    'Route planner showing the Cyprus E4 on a map',
                  ],
                  ['stages', 'Browse stage points', 'Cyprus E4 stage points'],
                  [
                    'elevation',
                    'Read the terrain',
                    'Cyprus E4 elevation profile',
                  ],
                ].map(([file, label, alt]) => (
                  <figure className={`phone-shot phone-${file}`} key={file}>
                    <Image
                      src={`/app-${file}.webp`}
                      alt={`EuroTrex iPhone app: ${alt}`}
                      width={720}
                      height={1565}
                      sizes="(max-width: 760px) 72vw, 250px"
                    />
                    <figcaption>{label}</figcaption>
                  </figure>
                ))}
              </div>
            </div>
            <div className="hiker-features">
              <ul className="feature-list">
                {features.map(([title, text]) => (
                  <li key={title}>
                    <span aria-hidden="true">✓</span>
                    <div>
                      <strong>{title}</strong>
                      <p>{text}</p>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </>
        )}
        <div className="hiker-launch-band">
          <Image
            className="app-icon"
            src="/eurotrex-app-icon-e4.webp"
            alt="EuroTrex app icon"
            width={256}
            height={256}
          />
          <div className="hiker-launch-copy">
            <p className="eyebrow">Eurotrex in your pocket</p>
            <h2 id={`${id}-title`}>Be first on the trail.</h2>
            <p>
              {appStore || playStore
                ? 'Find the app for your device, or ask about testing and availability.'
                : 'Private testing: invites and launch updates for iPhone and Android.'}
            </p>
          </div>
          <div
            className="hiker-launch-actions"
            aria-label="EuroTrex app availability"
            role="group"
          >
            <div className="store-item">
              {appStore ? (
                <a href={appStore} target="_blank" rel="noopener noreferrer">
                  <Image
                    src="/app-store-badge.svg"
                    alt="Download on the App Store"
                    width={180}
                    height={60}
                  />
                </a>
              ) : (
                <span
                  className="store-badge"
                  aria-label="iPhone app in private testing"
                >
                  <Image
                    src="/app-store-badge.svg"
                    alt=""
                    width={180}
                    height={60}
                  />
                </span>
              )}
            </div>
            <div className="store-item store-item-google">
              {playStore ? (
                <a href={playStore} target="_blank" rel="noopener noreferrer">
                  <Image
                    src="/google-play-badge.png"
                    alt="Get it on Google Play"
                    width={194}
                    height={75}
                  />
                </a>
              ) : (
                <span
                  className="store-badge"
                  aria-label="Android app in private testing"
                >
                  <Image
                    src="/google-play-badge.png"
                    alt=""
                    width={194}
                    height={75}
                  />
                </span>
              )}
            </div>
            <NotifyButton className="button button-primary">
              Notify Me
            </NotifyButton>
          </div>
        </div>
      </div>
    </section>
  );
}
