export function ScreenshotDialog() {
  return (
    <dialog
      id="screenshot-dialog"
      className="screenshot-dialog"
      aria-labelledby="screenshot-dialog-title"
      data-screenshot-dialog
    >
      <div className="screenshot-dialog-panel">
        <div className="screenshot-dialog-toolbar">
          <h2 id="screenshot-dialog-title">EuroTrex app</h2>
          <button
            type="button"
            className="button button-secondary screenshot-zoom"
            data-screenshot-zoom
            aria-pressed="false"
          >
            Zoom in
          </button>
          <button
            type="button"
            className="screenshot-close"
            data-screenshot-close
            aria-label="Close app screenshot"
            autoFocus
          >
            ×
          </button>
        </div>
        <div
          className="screenshot-dialog-image"
          tabIndex={0}
          aria-label="App screenshot; scroll to explore"
        >
          <img data-screenshot-image alt="" width={720} height={1565} />
        </div>
      </div>
    </dialog>
  );
}
