'use client';
import {useEffect, useId, useRef, useState} from 'react';
function dateKey(date: Date) {return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;}
function parse(value: string) {return value ? new Date(`${value}T12:00:00`) : new Date();}
const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
export function ReportDatePicker({value, onChange}: {value: string; onChange: (value: string) => void}) {
  const id = useId(), root = useRef<HTMLDivElement>(null), trigger = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false), [month, setMonth] = useState(() => parse(value)), [focused, setFocused] = useState(() => dateKey(parse(value)));
  const focusDay = useRef(false);
  const start = new Date(month.getFullYear(), month.getMonth(), 1, 12);
  start.setDate(start.getDate() - (start.getDay() + 6) % 7);
  const days = Array.from({length: 42}, (_, i) => {const day = new Date(start); day.setDate(day.getDate() + i); return day;});
  function close() {setOpen(false); trigger.current?.focus();}
  function choose(next: string) {onChange(next); close();}
  function move(date: Date, shouldFocus = true) {setMonth(new Date(date.getFullYear(), date.getMonth(), 1, 12)); setFocused(dateKey(date)); focusDay.current = shouldFocus;}
  function shiftMonth(amount: number) {
    const day = parse(focused);
    const next = new Date(day.getFullYear(), day.getMonth() + amount, 1, 12);
    next.setDate(Math.min(day.getDate(), new Date(next.getFullYear(), next.getMonth() + 1, 0).getDate()));
    move(next, false);
  }
  useEffect(() => {
    if (!open) return;
    const outside = (event: PointerEvent) => {if (!root.current?.contains(event.target as Node)) setOpen(false);};
    document.addEventListener('pointerdown', outside);
    return () => document.removeEventListener('pointerdown', outside);
  }, [open]);
  useEffect(() => {
    if (open && focusDay.current) {root.current?.querySelector<HTMLButtonElement>(`[data-day="${focused}"]`)?.focus(); focusDay.current = false;}
  }, [open, month, focused]);
  return <div className="report-date-field" ref={root} onKeyDown={event => {if (open && event.key === 'Escape') {event.preventDefault(); close();}}}>
    <span className="report-date-label" id={`${id}-label`}>Received since</span>
    <button ref={trigger} type="button" className="report-date-trigger" aria-labelledby={`${id}-label ${id}-value`} aria-haspopup="dialog" aria-expanded={open} aria-controls={`${id}-calendar`} onClick={() => {
      if (open) {setOpen(false); return;}
      move(parse(value)); setOpen(true);
    }}><span id={`${id}-value`}>{value ? parse(value).toLocaleDateString('en-GB', {day: 'numeric', month: 'short', year: 'numeric'}) : 'Any date'}</span><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true"><rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v5M17 3v5M3 11h18"/></svg></button>
    {open && <div id={`${id}-calendar`} className="report-calendar" role="dialog" aria-label="Choose received-since date">
      <div className="report-calendar-header"><button type="button" className="button button-secondary report-calendar-arrow" aria-label="Previous month" onClick={() => shiftMonth(-1)}>‹</button><strong aria-live="polite">{month.toLocaleDateString('en-GB', {month: 'long', year: 'numeric'})}</strong><button type="button" className="button button-secondary report-calendar-arrow" aria-label="Next month" onClick={() => shiftMonth(1)}>›</button></div>
      <div className="report-calendar-weekdays" aria-hidden="true">{weekdays.map(day => <span key={day}>{day}</span>)}</div>
      <div className="report-calendar-days" role="group" aria-label="Dates">
        {days.map(day => {const key = dateKey(day), selected = key === value, today = key === dateKey(new Date()); return <button key={key} type="button" data-day={key} className={`report-calendar-day ${day.getMonth() !== month.getMonth() ? 'outside-month' : ''} ${selected ? 'chosen' : ''} ${today ? 'today' : ''}`} tabIndex={key === focused ? 0 : -1} aria-pressed={selected} aria-current={today ? 'date' : undefined} aria-label={day.toLocaleDateString('en-GB', {weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'})} onFocus={() => setFocused(key)} onClick={() => choose(key)} onKeyDown={event => {
          const delta: Record<string, number> = {ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7, Home: -(day.getDay() + 6) % 7, End: 6 - (day.getDay() + 6) % 7};
          const next = new Date(day);
          if (event.key in delta) next.setDate(next.getDate() + delta[event.key]);
          else if (event.key === 'PageUp' || event.key === 'PageDown') {
            const targetMonth = day.getMonth() + (event.key === 'PageUp' ? -1 : 1);
            next.setDate(1); next.setMonth(targetMonth); next.setDate(Math.min(day.getDate(), new Date(next.getFullYear(), next.getMonth() + 1, 0).getDate()));
          } else return;
          event.preventDefault(); move(next);
        }}>{day.getDate()}</button>;})}
      </div>
      <div className="report-calendar-footer"><button type="button" className="button button-secondary" onClick={() => choose('')}>Clear</button><button type="button" className="button button-primary" onClick={() => choose(dateKey(new Date()))}>Today</button></div>
    </div>}
  </div>;
}
