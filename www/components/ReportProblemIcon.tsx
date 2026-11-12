const icons: Record<string, string> = {signpost: 'broken-signpost', vegetation: 'grass', obstruction: 'falling-rocks', path_damage: 'damaged-path', other: 'warning-amber'};

export function ReportProblemIcon({category}: {category: string}) {
  const icon = icons[category];
  return icon ? <img className="report-problem-icon" src={`/icons/report/${icon}.svg`} width="22" height="22" alt="" aria-hidden="true"/> : null;
}
