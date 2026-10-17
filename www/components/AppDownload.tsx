import Image from 'next/image';
import { NotifyButton } from './NotifyDialog';

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
      className="section-shell app-download-section"
      id={id}
      aria-labelledby={`${id}-title`}
    >
      {screenshots && (
        <div className="download-overview">
          <div>
            <p className="eyebrow">Take Cyprus-E4 in your pocket</p>
            <h2>
              Plan less.
              <br />
              Discover more.
            </h2>
            <p>
              Offline maps, flexible walking days, elevation profiles and places
              to stay, together in the EuroTrex E4 app.
            </p>
          </div>
          <div className="download-screenshots">
            {[
              ['app-stages', 'Browse stage points'],
              ['app-planner', 'Shape your trip'],
              ['app-elevation', 'Read the terrain'],
            ].map(([file, label]) => (
              <figure key={file}>
                <Image
                  src={`/${file}.webp`}
                  alt={`EuroTrex iPhone app: ${label}`}
                  width={720}
                  height={1565}
                  sizes="(max-width: 760px) 28vw, 180px"
                />
                <figcaption>{label}</figcaption>
              </figure>
            ))}
          </div>
        </div>
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
          <h2 id={`${id}-title`}>Get the Eurotrex E4 App</h2>
          <p>
            {appStore || playStore
              ? 'Find the app for your device, or ask about testing and availability.'
              : 'Private testing: invites and launch updates for iPhone and Android.'}
          </p>
        </div>
        <div className="hiker-launch-actions">
          {appStore && (
            <a href={appStore} target="_blank" rel="noopener noreferrer">
              <Image
                src="/app-store-badge.svg"
                alt="Download on the App Store"
                width={120}
                height={40}
              />
            </a>
          )}
          {playStore && (
            <a href={playStore} target="_blank" rel="noopener noreferrer">
              <Image
                src="/google-play-badge.png"
                alt="Get it on Google Play"
                width={135}
                height={40}
              />
            </a>
          )}
          <NotifyButton className="button button-primary">
            Notify Me
          </NotifyButton>
        </div>
      </div>
    </section>
  );
}
