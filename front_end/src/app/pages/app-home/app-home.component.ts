import {
  Component,
  OnInit,
  OnDestroy,
  ChangeDetectorRef,
  ChangeDetectionStrategy,
  ElementRef,
  ViewChild,
  ViewChildren,
  QueryList,
  NgZone,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';

import { HouseholdStateService } from '../../services/household-state.service';
import { AppAuthService } from '../../services/app-auth.service';
import { NotesService, Note } from '../../services/notes.service';
import { SocketService } from '../../services/socket.service';

const NOTE_WIDTH = 160;
const DEFAULT_NOTE_COLOR = '#fff9c4';
const DEFAULT_TEXT_SIZE = 14;
const DEFAULT_TEXT_COLOR = '#333';

function darkenHex(hex: string, amount: number): string {
  const c = hex.replace('#', '');
  const r = Math.round(parseInt(c.slice(0, 2), 16) * (1 - amount));
  const g = Math.round(parseInt(c.slice(2, 4), 16) * (1 - amount));
  const b = Math.round(parseInt(c.slice(4, 6), 16) * (1 - amount));
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
}

@Component({
  selector: 'app-app-home',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app-home.component.html',
  styleUrls: ['./app-home.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppHomeComponent implements OnInit, OnDestroy {
  @ViewChild('board', { static: false }) boardRef!: ElementRef<HTMLDivElement>;
  @ViewChildren('noteTextarea') noteTextareas!: QueryList<ElementRef<HTMLTextAreaElement>>;

  householdId: number | null = null;
  notes: Note[] = [];
  loading = true;

  // 3-dot menu state
  openMenuNoteId: number | null = null;

  // Max zIndex currently in use
  private maxZ = 1;

  // Drag state
  private dragging: {
    noteId: number;
    startMouseX: number;
    startMouseY: number;
    startPosX: number; // percentage
    startPosY: number; // pixels
  } | null = null;

  // Debounce timers for text saves: noteId -> timer handle
  private saveTimers = new Map<number, ReturnType<typeof setTimeout>>();

  // Document click listener reference for closing menus
  private docClickListener = (e: MouseEvent) => this.onDocumentClick(e);

  private subs = new Subscription();

  constructor(
    private householdState: HouseholdStateService,
    private appAuthService: AppAuthService,
    private notesService: NotesService,
    private socketService: SocketService,
    private cdr: ChangeDetectorRef,
    private zone: NgZone,
  ) {}

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (household) {
      this.householdId = household.householdId;
      this.loadNotes();
      this.connectSocket();
    }

    this.subs.add(
      this.householdState.selectedHousehold$.subscribe(h => {
        if (h && h.householdId !== this.householdId) {
          this.householdId = h.householdId;
          this.loadNotes();
          this.socketService.disconnect();
          this.connectSocket();
        }
      })
    );

    this.subs.add(
      this.socketService.noteCreated$.subscribe(note => {
        if (!this.notes.find(n => n.id === note.id)) {
          this.notes = [...this.notes, this.applyDefaults(note as any)];
          this.maxZ = Math.max(this.maxZ, note.zIndex);
          this.cdr.markForCheck();
        }
      })
    );

    this.subs.add(
      this.socketService.noteUpdated$.subscribe(updated => {
        const updatedNote = this.applyDefaults(updated as any);
        this.notes = this.notes.map(n => n.id === updatedNote.id ? updatedNote : n);
        this.maxZ = Math.max(this.maxZ, updatedNote.zIndex);
        // If the textarea for this note is not focused, update its value programmatically
        this.updateTextareaIfNotFocused(updatedNote);
        this.cdr.markForCheck();
      })
    );

    this.subs.add(
      this.socketService.noteDeleted$.subscribe(id => {
        this.notes = this.notes.filter(n => n.id !== id);
        this.cdr.markForCheck();
      })
    );

    document.addEventListener('click', this.docClickListener, true);
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
    this.socketService.disconnect();
    this.removeDragListeners();
    document.removeEventListener('click', this.docClickListener, true);
    this.saveTimers.forEach(t => clearTimeout(t));
    this.saveTimers.clear();
  }

  private connectSocket(): void {
    const token = this.appAuthService.getToken();
    if (token && this.householdId) {
      this.socketService.connect(this.householdId, token);
    }
  }

  private applyDefaults(note: Note): Note {
    const bodyColor = note.noteColor ?? DEFAULT_NOTE_COLOR;
    return {
      ...note,
      noteColor: bodyColor,
      headerColor: note.headerColor ?? darkenHex(bodyColor, 0.12),
      textDirection: note.textDirection ?? 'auto',
      textSize: note.textSize ?? DEFAULT_TEXT_SIZE,
      isBold: note.isBold ?? false,
      isUnderline: note.isUnderline ?? false,
      textColor: note.textColor ?? DEFAULT_TEXT_COLOR,
    };
  }

  loadNotes(): void {
    if (!this.householdId) return;
    this.loading = true;
    this.cdr.markForCheck();

    this.notesService.list(this.householdId).subscribe({
      next: res => {
        this.notes = (res.notes ?? []).map(n => this.applyDefaults(n));
        this.maxZ = this.notes.reduce((max, n) => Math.max(max, n.zIndex), 1);
        this.loading = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.loading = false;
        this.cdr.markForCheck();
      }
    });
  }

  addNote(): void {
    if (!this.householdId) return;

    // Stack new note below existing ones
    const maxPosY = this.notes.reduce((max, n) => Math.max(max, n.posY), -Infinity);
    const posY = isFinite(maxPosY) ? maxPosY + 220 : 40;
    const posX = 10; // 10% from left

    this.notesService.create({
      content: '',
      posX,
      posY,
      zIndex: ++this.maxZ,
      householdId: this.householdId,
    }).subscribe({
      next: res => {
        const note = this.applyDefaults(res.note);
        if (!this.notes.find(n => n.id === note.id)) {
          this.notes = [...this.notes, note];
          this.cdr.markForCheck();
        }
      },
      error: () => alert('Failed to create note.'),
    });
  }

  deleteNote(note: Note, event: Event): void {
    event.stopPropagation();
    if (this.openMenuNoteId === note.id) {
      this.openMenuNoteId = null;
    }
    this.notesService.delete(note.id).subscribe({
      error: () => alert('Failed to delete note.'),
    });
    // Optimistic remove
    this.notes = this.notes.filter(n => n.id !== note.id);
    this.cdr.markForCheck();
  }

  // ── Text input with debounce ────────────────────────────────────────────────

  onNoteInput(note: Note, content: string): void {
    // Update local state immediately
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, content } : n);

    // Debounce the HTTP save
    const existing = this.saveTimers.get(note.id);
    if (existing) clearTimeout(existing);
    const timer = setTimeout(() => {
      this.saveTimers.delete(note.id);
      this.notesService.update(note.id, { content }).subscribe({ error: () => {} });
    }, 800);
    this.saveTimers.set(note.id, timer);
  }

  // Update textarea DOM value when socket event arrives and textarea is not focused
  private updateTextareaIfNotFocused(updatedNote: Note): void {
    if (!this.noteTextareas) return;
    const textareas = this.noteTextareas.toArray();
    // Find the textarea whose data-note-id matches
    const el = textareas.find(ta => ta.nativeElement.getAttribute('data-note-id') === String(updatedNote.id));
    if (el && document.activeElement !== el.nativeElement) {
      el.nativeElement.value = updatedNote.content;
    }
  }

  // ── Text direction ──────────────────────────────────────────────────────────

  getTextDirection(note: Note): 'ltr' | 'rtl' {
    const dir = note.textDirection ?? 'auto';
    if (dir === 'ltr') return 'ltr';
    if (dir === 'rtl') return 'rtl';
    // Auto: detect by counting Hebrew characters
    const content = note.content ?? '';
    if (!content) return 'ltr';
    const hebrewCount = (content.match(/[\u0590-\u05FF]/g) ?? []).length;
    return hebrewCount / content.length > 0.3 ? 'rtl' : 'ltr';
  }

  // ── Note left position (px) from posX percentage ───────────────────────────

  getNoteLeft(note: Note): number {
    const boardWidth = this.boardRef?.nativeElement.offsetWidth ?? window.innerWidth;
    return note.posX / 100 * (boardWidth - NOTE_WIDTH);
  }

  // ── Board height: grows to fit all notes ───────────────────────────────────

  getBoardHeight(): number {
    const viewportH = window.innerHeight;
    if (!this.notes.length) return viewportH;
    const maxBottom = this.notes.reduce((max, n) => Math.max(max, n.posY + 200), 0);
    return Math.max(maxBottom + 200, viewportH);
  }

  // ── 3-dot menu ─────────────────────────────────────────────────────────────

  toggleMenu(note: Note, event: Event): void {
    event.stopPropagation();
    this.openMenuNoteId = this.openMenuNoteId === note.id ? null : note.id;
    this.cdr.markForCheck();
  }

  private onDocumentClick(e: MouseEvent): void {
    if (this.openMenuNoteId === null) return;
    const target = e.target as HTMLElement;
    // Close if click is outside any note-menu or options-btn
    if (!target.closest('.note-menu') && !target.closest('.note-options-btn')) {
      this.zone.run(() => {
        this.openMenuNoteId = null;
        this.cdr.markForCheck();
      });
    }
  }

  getMenuPosition(note: Note): { top: number; left: number } {
    const noteLeft = this.getNoteLeft(note);
    // Position menu above the note header, fixed to viewport
    // We need the board's bounding rect to convert note coords to viewport coords
    const boardEl = this.boardRef?.nativeElement;
    const boardRect = boardEl ? boardEl.getBoundingClientRect() : { top: 0, left: 0 };
    const scrollTop = boardEl?.scrollTop ?? 0;

    const menuTop = boardRect.top + note.posY - scrollTop - 4; // just above the note
    const menuLeft = boardRect.left + noteLeft;
    return { top: menuTop, left: menuLeft };
  }

  // ── Note styling updates ────────────────────────────────────────────────────

  setNoteColor(note: Note, color: string, event: Event): void {
    event.stopPropagation();
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, noteColor: color } : n);
    this.notesService.update(note.id, { noteColor: color }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  setTextDirection(note: Note, dir: 'ltr' | 'rtl' | 'auto', event: Event): void {
    event.stopPropagation();
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, textDirection: dir } : n);
    this.notesService.update(note.id, { textDirection: dir }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  changeFontSize(note: Note, delta: number, event: Event): void {
    event.stopPropagation();
    const current = note.textSize ?? DEFAULT_TEXT_SIZE;
    const next = Math.min(24, Math.max(10, current + delta));
    if (next === current) return;
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, textSize: next } : n);
    this.notesService.update(note.id, { textSize: next }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  toggleBold(note: Note, event: Event): void {
    event.stopPropagation();
    const next = !note.isBold;
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, isBold: next } : n);
    this.notesService.update(note.id, { isBold: next }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  toggleUnderline(note: Note, event: Event): void {
    event.stopPropagation();
    const next = !note.isUnderline;
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, isUnderline: next } : n);
    this.notesService.update(note.id, { isUnderline: next }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  setTextColor(note: Note, color: string, event: Event): void {
    event.stopPropagation();
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, textColor: color } : n);
    this.notesService.update(note.id, { textColor: color }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  setHeaderColor(note: Note, color: string, event: Event): void {
    event.stopPropagation();
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, headerColor: color } : n);
    this.notesService.update(note.id, { headerColor: color }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  // ── Drag handling ───────────────────────────────────────────────────────────

  startDrag(note: Note, event: MouseEvent | TouchEvent): void {
    // Don't start drag if clicking on interactive elements
    const target = event.target as HTMLElement;
    if (target.closest('textarea') || target.closest('button') || target.closest('.note-menu')) {
      return;
    }
    event.preventDefault();

    // Bring to front
    this.bringToFront(note);

    const { clientX, clientY } = this.getEventCoords(event);

    this.dragging = {
      noteId: note.id,
      startMouseX: clientX,
      startMouseY: clientY,
      startPosX: note.posX,  // percentage
      startPosY: note.posY,  // pixels
    };

    this.zone.runOutsideAngular(() => {
      window.addEventListener('mousemove', this.onDragMove);
      window.addEventListener('touchmove', this.onDragMove, { passive: false });
      window.addEventListener('mouseup', this.onDragEnd);
      window.addEventListener('touchend', this.onDragEnd);
    });
  }

  private onDragMove = (event: MouseEvent | TouchEvent): void => {
    if (!this.dragging) return;
    if (event instanceof TouchEvent) event.preventDefault();

    const { clientX, clientY } = this.getEventCoords(event);
    const dx = clientX - this.dragging.startMouseX;
    const dy = clientY - this.dragging.startMouseY;

    const boardEl = this.boardRef?.nativeElement;
    const boardWidth = boardEl ? boardEl.offsetWidth : window.innerWidth;

    // Convert pixel dx to percentage delta
    const dxPercent = (dx / (boardWidth - NOTE_WIDTH)) * 100;
    const newPosX = Math.min(100, Math.max(0, this.dragging.startPosX + dxPercent));
    const newPosY = Math.max(0, this.dragging.startPosY + dy);

    this.zone.run(() => {
      this.notes = this.notes.map(n =>
        n.id === this.dragging!.noteId ? { ...n, posX: newPosX, posY: newPosY } : n
      );
      this.cdr.markForCheck();
    });
  };

  private onDragEnd = (): void => {
    if (!this.dragging) return;
    const { noteId } = this.dragging;
    this.dragging = null;
    this.removeDragListeners();

    const note = this.notes.find(n => n.id === noteId);
    if (note) {
      this.notesService.update(noteId, { posX: note.posX, posY: note.posY }).subscribe({ error: () => {} });
    }
  };

  private removeDragListeners(): void {
    window.removeEventListener('mousemove', this.onDragMove);
    window.removeEventListener('touchmove', this.onDragMove);
    window.removeEventListener('mouseup', this.onDragEnd);
    window.removeEventListener('touchend', this.onDragEnd);
  }

  private bringToFront(note: Note): void {
    this.maxZ++;
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, zIndex: this.maxZ } : n);
    this.notesService.update(note.id, { zIndex: this.maxZ }).subscribe({ error: () => {} });
    this.cdr.markForCheck();
  }

  private getEventCoords(event: MouseEvent | TouchEvent): { clientX: number; clientY: number } {
    if (event instanceof TouchEvent) {
      const t = event.touches[0] ?? event.changedTouches[0];
      return { clientX: t.clientX, clientY: t.clientY };
    }
    return { clientX: event.clientX, clientY: event.clientY };
  }

  trackNote(_: number, note: Note): number {
    return note.id;
  }
}
