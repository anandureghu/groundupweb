type StoreBadgesProps = {
  iosUrl?: string;
  androidUrl?: string;
  className?: string;
};

const APP_STORE_BADGE_SRC = "/assets/badges/app-store.png";
const GOOGLE_PLAY_BADGE_SRC = "/assets/badges/google-play.png";

export function StoreBadges({
  iosUrl,
  androidUrl,
  className,
}: StoreBadgesProps) {
  if (!iosUrl && !androidUrl) {
    return null;
  }

  return (
    <div
      className={
        className ??
        "flex flex-wrap items-center justify-center gap-3 pt-2"
      }
    >
      {iosUrl ? (
        <a
          href={iosUrl}
          target="_blank"
          rel="noreferrer"
          aria-label="Download on the App Store"
          className="inline-flex h-12 w-[160px] items-center justify-center transition-opacity hover:opacity-90"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={APP_STORE_BADGE_SRC}
            alt="Download on the App Store"
            width={160}
            height={48}
            className="h-full w-full object-contain object-center"
          />
        </a>
      ) : null}
      {androidUrl ? (
        <a
          href={androidUrl}
          target="_blank"
          rel="noreferrer"
          aria-label="Get it on Google Play"
          className="inline-flex h-12 w-[160px] items-center justify-center transition-opacity hover:opacity-90"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={GOOGLE_PLAY_BADGE_SRC}
            alt="Get it on Google Play"
            width={160}
            height={48}
            className="h-full w-full scale-[1.35] object-contain object-center"
          />
        </a>
      ) : null}
    </div>
  );
}
