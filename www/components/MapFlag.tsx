// Same 42px artwork and colours as mobile map_flag_marker.dart.
export function MapFlag({ finish = false }: { finish?: boolean }) {
  return (
    <svg viewBox="0 0 42 42" aria-hidden="true" className="route-flag-icon">
      <circle cx="21" cy="22.5" r="18.5" fill="#000" opacity=".15" />
      <circle cx="21" cy="21" r="17.5" fill="white" />
      <circle cx="21" cy="21" r="14.5" fill={finish ? '#d14b45' : '#277653'} />
      <path
        d="M17 12.5V30.5"
        stroke="white"
        strokeWidth="2.5"
        strokeLinecap="round"
      />
      <path
        d="M17 13.5C22 10.5 26.5 14.5 31.5 12V21.5C26.5 24 22 20 17 22.5Z"
        fill="white"
      />
    </svg>
  );
}
