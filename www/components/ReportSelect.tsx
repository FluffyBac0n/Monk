'use client';
import {useEffect, useId, useRef, useState} from 'react';

type Option = {value: string; label: string};

/** A select-only combobox with the same surface and controls as the report calendar. */
export function ReportSelect({label, value, options, onChange, disabled = false}: {
  label: string; value: string; options: Option[]; onChange: (value: string) => void; disabled?: boolean;
}) {
  const id = useId(), root = useRef<HTMLDivElement>(null), trigger = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false), [active, setActive] = useState(0), [above, setAbove] = useState(false);
  const search = useRef({text: '', time: 0});
  const selected = options.findIndex(option => option.value === value);
  function show(index = Math.max(0, selected)) {
    const bounds = trigger.current?.getBoundingClientRect();
    setAbove(!!bounds && window.innerHeight - bounds.bottom < 310 && bounds.top > 310);
    setActive(index); setOpen(true);
  }
  function choose(index: number) {
    if (options[index]) onChange(options[index].value);
    setOpen(false); trigger.current?.focus();
  }
  useEffect(() => {
    if (!open) return;
    const outside = (event: PointerEvent) => {if (!root.current?.contains(event.target as Node)) setOpen(false);};
    document.addEventListener('pointerdown', outside);
    return () => document.removeEventListener('pointerdown', outside);
  }, [open]);
  useEffect(() => {
    if (open) root.current?.querySelector(`#${CSS.escape(id)}-option-${active}`)?.scrollIntoView({block: 'nearest'});
  }, [open, active, id]);
  return <div className="report-select-field" ref={root} onBlur={event => {
    if (!event.currentTarget.contains(event.relatedTarget)) setOpen(false);
  }}>
    <span className="report-date-label" id={`${id}-label`}>{label}</span>
    <button type="button" ref={trigger} className="report-date-trigger report-select-trigger" role="combobox"
      aria-labelledby={`${id}-label`} aria-expanded={open} aria-controls={`${id}-list`}
      aria-haspopup="listbox" aria-activedescendant={open ? `${id}-option-${active}` : undefined}
      disabled={disabled || !options.length} onClick={() => open ? setOpen(false) : show()}
      onKeyDown={event => {
        const last = options.length - 1;
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault();
          if (!open) show(); else setActive(index => Math.max(0, Math.min(last, index + (event.key === 'ArrowDown' ? 1 : -1))));
        } else if (event.key === 'Home' || event.key === 'End') {
          event.preventDefault(); const next = event.key === 'Home' ? 0 : last;
          if (open) setActive(next); else show(next);
        } else if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault(); if (open) choose(active); else show();
        } else if (event.key === 'Escape') {event.preventDefault(); setOpen(false);}
        else if (event.key === 'Tab') setOpen(false);
        else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
          event.preventDefault();
          const now = Date.now(), previous = now - search.current.time < 700 ? search.current.text : '';
          const text = previous + event.key.toLowerCase(); search.current = {text, time: now};
          const match = options.findIndex(option => option.label.toLowerCase().startsWith(text));
          if (match >= 0) {if (open) setActive(match); else show(match);}
        }
      }}>
      <span>{options[selected]?.label ?? 'Choose an option'}</span>
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>
    </button>
    {open && <div id={`${id}-list`} className={`report-select-menu ${above ? 'opens-above' : ''}`} role="listbox" aria-labelledby={`${id}-label`}>
      {options.map((option, index) => <div key={option.value} id={`${id}-option-${index}`} role="option"
        aria-selected={option.value === value} className={`report-select-option ${index === active ? 'active' : ''}`}
        onPointerDown={event => event.preventDefault()} onPointerMove={() => setActive(index)} onClick={() => choose(index)}>
        <span>{option.label}</span><span aria-hidden="true">{option.value === value ? '✓' : ''}</span>
      </div>)}
    </div>}
  </div>;
}
