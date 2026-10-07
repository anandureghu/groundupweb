type StoreBadgesProps = {
  iosUrl?: string;
  androidUrl?: string;
  className?: string;
};

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
          className="transition-opacity hover:opacity-90"
        >
          <AppStoreBadge />
        </a>
      ) : null}
      {androidUrl ? (
        <a
          href={androidUrl}
          target="_blank"
          rel="noreferrer"
          aria-label="Get it on Google Play"
          className="transition-opacity hover:opacity-90"
        >
          <GooglePlayBadge />
        </a>
      ) : null}
    </div>
  );
}

function AppStoreBadge() {
  return (
    <svg
      width="148"
      height="44"
      viewBox="0 0 148 44"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
    >
      <title>Download on the App Store</title>
      <rect width="148" height="44" rx="8" fill="#000000" />
      <path
        d="M28.4 21.6c0-2.5 2-3.7 2.1-3.8-1.2-1.7-3-1.9-3.6-1.9-1.5-.2-3 .9-3.8.9-.8 0-2-.9-3.3-.8-1.7 0-3.3 1-4.2 2.5-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.3 2.5 1.3 0 1.8-.8 3.4-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.2 3.2-2.4.9-1.4 1.3-2.7 1.3-2.8-.1 0-2.5-1-2.5-3.8zm-2.3-6.7c.7-.9 1.2-2.1 1.1-3.3-1 .1-2.3.7-3 1.6-.7.8-1.3 2.1-1.1 3.3 1.2.1 2.4-.6 3-1.6z"
        fill="white"
      />
      <text
        x="42"
        y="17"
        fill="white"
        fontFamily="system-ui, -apple-system, sans-serif"
        fontSize="8"
      >
        Download on the
      </text>
      <text
        x="42"
        y="31"
        fill="white"
        fontFamily="system-ui, -apple-system, sans-serif"
        fontSize="14"
        fontWeight="600"
      >
        App Store
      </text>
    </svg>
  );
}

function GooglePlayBadge() {
  return (
    <svg
      width="148"
      height="44"
      viewBox="0 0 148 44"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
    >
      <title>Get it on Google Play</title>
      <rect width="148" height="44" rx="8" fill="#000000" />
      <path d="M22 12.5l12.5 7.2L22 26.9V12.5z" fill="#EA4335" />
      <path d="M22 26.9l12.5-7.2 4.2 2.4L22 33.5v-6.6z" fill="#FBBC04" />
      <path d="M22 12.5v14.4l-8.5-4.9V17.4L22 12.5z" fill="#4285F4" />
      <path d="M38.7 21.9l-4.2-2.4 4.2-2.4 2.3 1.3c.7.4.7 1.5 0 1.9l-2.3 1.6z" fill="#34A853" />
      <text
        x="48"
        y="17"
        fill="white"
        fontFamily="system-ui, -apple-system, sans-serif"
        fontSize="8"
      >
        GET IT ON
      </text>
      <text
        x="48"
        y="31"
        fill="white"
        fontFamily="system-ui, -apple-system, sans-serif"
        fontSize="14"
        fontWeight="600"
      >
        Google Play
      </text>
    </svg>
  );
}
