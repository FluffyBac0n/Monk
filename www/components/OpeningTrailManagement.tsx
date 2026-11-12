export function OpeningTrailManagement({fullScreen=false}:{fullScreen?:boolean}) {
  return <div className={fullScreen?'loading-screen era-opening':'era-opening'} role="status" aria-live="polite"><p>Opening Trail Management…</p><div className="era-loading-track" role="progressbar" aria-label="Opening Trail Management"><span/></div></div>;
}
