import {
  Component,
  OnInit,
  OnDestroy,
  AfterViewInit,
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

import { TranslateModule } from '@ngx-translate/core';

import { HouseholdStateService } from '../../services/household-state.service';
import { AppAuthService } from '../../services/app-auth.service';
import { NotesService, Note } from '../../services/notes.service';
import { SocketService } from '../../services/socket.service';

const NOTE_WIDTH = 160;
const DEFAULT_NOTE_COLOR = '#fff9c4';
const DEFAULT_TEXT_SIZE = 14;
const DEFAULT_TEXT_COLOR = '#333';
const DEFAULT_HEART_COLOR = '#e91e63';
const DEFAULT_HEART_SIZE = 120;
const DEFAULT_IMAGE_WIDTH = 180;
const DEFAULT_IMAGE_HEIGHT = 140;

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
  imports: [CommonModule, FormsModule, TranslateModule],
  templateUrl: './app-home.component.html',
  styleUrls: ['./app-home.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppHomeComponent implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild('boardContainer', { static: false }) boardContainerRef!: ElementRef<HTMLDivElement>;
  @ViewChild('board', { static: false }) boardRef!: ElementRef<HTMLDivElement>;
  @ViewChild('imageFileInput', { static: false }) imageFileInput!: ElementRef<HTMLInputElement>;
  @ViewChildren('noteTextarea') noteTextareas!: QueryList<ElementRef<HTMLTextAreaElement>>;

  householdId: number | null = null;
  notes: Note[] = [];
  loading = true;

  // FAB speed-dial
  showFabMenu = false;

  // 3-dot menu state
  openMenuNoteId: number | null = null;

  // Selection
  selectedNoteId: number | null = null;

  // Rotation drag
  private rotating: {
    noteId: number;
    centerX: number;
    centerY: number;
    startAngle: number;
    startRotation: number;
  } | null = null;

  // Background
  showBgPanel = false;
  boardBgIndex = 0;
  boardBgColor: string | null = null;

  readonly BOARD_BG_DEFS = [
    { label: 'Dots',     icon: '·',  defaultColor: '#c5caf7', bgColor: '#f4f5ff', getPattern: (c: string) => `radial-gradient(circle, ${c} 1.5px, transparent 1.5px)`,                                                                                   bgSize: '28px 28px' },
    { label: 'Grid',     icon: '#',  defaultColor: '#d8dcff', bgColor: '#ffffff', getPattern: (c: string) => `linear-gradient(${c} 1px, transparent 1px), linear-gradient(90deg, ${c} 1px, transparent 1px)`,                                            bgSize: '28px 28px' },
    { label: 'Diagonal', icon: '/',  defaultColor: '#f0d4e8', bgColor: '#fff8fd', getPattern: (c: string) => `repeating-linear-gradient(45deg, ${c} 0, ${c} 1px, transparent 0, transparent 50%)`,                                                       bgSize: '20px 20px' },
    { label: 'Linen',    icon: '≡',  defaultColor: '#e0d8c8', bgColor: '#fdf8f0', getPattern: (c: string) => `repeating-linear-gradient(0deg, ${c} 0, ${c} 1px, transparent 0, transparent 100%)`,                                                      bgSize: '100% 32px' },
    { label: 'Plain',    icon: '■',  defaultColor: '#e0e8f0', bgColor: '#f0f4f8', getPattern: (_c: string) => 'none',                                                                                                                                    bgSize: 'auto' },
  ];

  // Delete confirmation
  pendingDeleteNote: Note | null = null;

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

  // Resize state
  private resizing: {
    noteId: number;
    startMouseX: number;
    startMouseY: number;
    startWidth: number;
    startHeight: number;
    aspectRatio: number | null; // non-null for image notes
  } | null = null;

  // Pinch gesture state (two-finger resize + rotate)
  private pinching: {
    noteId: number;
    startDist: number;
    startAngle: number;
    startWidth: number;
    startHeight: number;
    startRotation: number;
    aspectRatio: number | null;
  } | null = null;

  // Debounce timers for text saves: noteId -> timer handle
  private saveTimers = new Map<number, ReturnType<typeof setTimeout>>();

  // Document click listener reference for closing menus/fab
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

    try {
      const savedBg = localStorage.getItem('board-bg');
      if (savedBg) {
        const { index, color } = JSON.parse(savedBg);
        this.boardBgIndex = index ?? 0;
        this.boardBgColor = color ?? null;
      }
    } catch {}
  }

  ngAfterViewInit(): void {
    // boardRef is now available — recalculate note positions with correct board width
    this.cdr.markForCheck();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
    this.socketService.disconnect();
    this.removeDragListeners();
    this.removeResizeListeners();
    this.removeRotateListeners();
    this.removePinchListeners();
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
      type: note.type ?? 'text',
      noteColor: bodyColor,
      headerColor: note.headerColor ?? darkenHex(bodyColor, 0.12),
      textDirection: note.textDirection ?? 'auto',
      textSize: note.textSize ?? DEFAULT_TEXT_SIZE,
      isBold: note.isBold ?? false,
      isUnderline: note.isUnderline ?? false,
      textColor: note.textColor ?? DEFAULT_TEXT_COLOR,
      heartColor: note.heartColor ?? DEFAULT_HEART_COLOR,
      width: note.width ?? null,
      height: note.height ?? null,
      rotation: note.rotation ?? 0,
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

  // ── FAB speed-dial ──────────────────────────────────────────────────────────

  toggleFabMenu(event: Event): void {
    event.stopPropagation();
    this.showFabMenu = !this.showFabMenu;
    if (!this.showFabMenu) this.showBgPanel = false;
    this.cdr.markForCheck();
  }

  addNote(): void {
    this.showFabMenu = false;
    if (!this.householdId) return;

    const posY = this.getNextPosY();

    this.notesService.create({
      content: '',
      posX: 10,
      posY,
      zIndex: ++this.maxZ,
      householdId: this.householdId,
      type: 'text',
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

  addHeart(): void {
    this.showFabMenu = false;
    if (!this.householdId) return;

    this.notesService.create({
      content: '',
      posX: 20,
      posY: this.getNextPosY(),
      zIndex: ++this.maxZ,
      householdId: this.householdId,
      type: 'heart',
      heartColor: DEFAULT_HEART_COLOR,
      width: DEFAULT_HEART_SIZE,
      height: DEFAULT_HEART_SIZE,
    }).subscribe({
      next: res => {
        const note = this.applyDefaults(res.note);
        if (!this.notes.find(n => n.id === note.id)) {
          this.notes = [...this.notes, note];
          this.cdr.markForCheck();
        }
      },
      error: () => alert('Failed to create heart.'),
    });
  }

  triggerImageUpload(): void {
    this.showFabMenu = false;
    this.cdr.markForCheck();
    setTimeout(() => this.imageFileInput?.nativeElement.click(), 50);
  }

  onImageFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file || !this.householdId) return;

    // Reset so same file can be re-selected
    input.value = '';

    const reader = new FileReader();
    reader.onload = () => {
      const base64 = reader.result as string;
      this.zone.run(() => {
        this.notesService.create({
          content: base64,
          posX: 30,
          posY: this.getNextPosY(),
          zIndex: ++this.maxZ,
          householdId: this.householdId!,
          type: 'image',
          width: DEFAULT_IMAGE_WIDTH,
          height: DEFAULT_IMAGE_HEIGHT,
        }).subscribe({
          next: res => {
            const note = this.applyDefaults(res.note);
            if (!this.notes.find(n => n.id === note.id)) {
              this.notes = [...this.notes, note];
              this.cdr.markForCheck();
            }
          },
          error: () => alert('Failed to upload image.'),
        });
      });
    };
    reader.readAsDataURL(file);
  }

  private getNextPosY(): number {
    const maxPosY = this.notes.reduce((max, n) => Math.max(max, n.posY), -Infinity);
    return isFinite(maxPosY) ? maxPosY + 220 : 40;
  }

  deleteNote(note: Note, event: Event): void {
    event.stopPropagation();
    if (this.openMenuNoteId === note.id) {
      this.openMenuNoteId = null;
    }
    this.pendingDeleteNote = note;
    this.cdr.markForCheck();
  }

  confirmDeleteNote(): void {
    const note = this.pendingDeleteNote;
    if (!note) return;
    this.pendingDeleteNote = null;
    this.notesService.delete(note.id).subscribe({
      error: () => alert('Failed to delete.'),
    });
    this.notes = this.notes.filter(n => n.id !== note.id);
    this.cdr.markForCheck();
  }

  cancelDeleteNote(): void {
    this.pendingDeleteNote = null;
    this.cdr.markForCheck();
  }

  // ── Text input with debounce ────────────────────────────────────────────────

  onNoteInput(note: Note, content: string): void {
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, content } : n);

    const existing = this.saveTimers.get(note.id);
    if (existing) clearTimeout(existing);
    const timer = setTimeout(() => {
      this.saveTimers.delete(note.id);
      this.notesService.update(note.id, { content }).subscribe({ error: () => {} });
    }, 800);
    this.saveTimers.set(note.id, timer);
  }

  private updateTextareaIfNotFocused(updatedNote: Note): void {
    if (!this.noteTextareas) return;
    const textareas = this.noteTextareas.toArray();
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
    const content = note.content ?? '';
    if (!content) return 'ltr';
    const hebrewCount = (content.match(/[\u0590-\u05FF]/g) ?? []).length;
    return hebrewCount / content.length > 0.3 ? 'rtl' : 'ltr';
  }

  // ── Position helpers ────────────────────────────────────────────────────────

  getStickerWidth(note: Note): number {
    if (note.type === 'text') return note.width ?? NOTE_WIDTH;
    return note.width ?? (note.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_WIDTH);
  }

  getNoteLeft(note: Note): number {
    const boardWidth = this.boardRef?.nativeElement.offsetWidth ?? window.innerWidth;
    const w = this.getStickerWidth(note);
    return Math.max(0, note.posX / 100 * (boardWidth - w));
  }

  getBoardHeight(): number {
    const viewportH = window.innerHeight;
    if (!this.notes.length) return viewportH;
    const maxBottom = this.notes.reduce((max, n) => {
      const h = n.type === 'text' ? 200 : (n.height ?? (n.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_HEIGHT));
      return Math.max(max, n.posY + h);
    }, 0);
    return Math.max(maxBottom + 200, viewportH);
  }

  // ── 3-dot menu ─────────────────────────────────────────────────────────────

  toggleMenu(note: Note, event: Event): void {
    event.stopPropagation();
    this.openMenuNoteId = this.openMenuNoteId === note.id ? null : note.id;
    this.cdr.markForCheck();
  }

  private onDocumentClick(e: MouseEvent): void {
    const target = e.target as HTMLElement;
    let needsCheck = false;

    if (this.openMenuNoteId !== null) {
      if (!target.closest('.note-menu') && !target.closest('.note-options-btn')) {
        this.openMenuNoteId = null;
        needsCheck = true;
      }
    }
    if (this.showFabMenu) {
      if (!target.closest('.fab-container')) {
        this.showFabMenu = false;
        needsCheck = true;
      }
    }
    if (this.showBgPanel) {
      if (!target.closest('.fab-container')) {
        this.showBgPanel = false;
        needsCheck = true;
      }
    }
    if (this.selectedNoteId !== null) {
      if (
        !target.closest('.sticky-note') &&
        !target.closest('.heart-sticker') &&
        !target.closest('.image-sticker') &&
        !target.closest('.note-menu')
      ) {
        this.selectedNoteId = null;
        needsCheck = true;
      }
    }
    if (needsCheck) {
      this.zone.run(() => this.cdr.markForCheck());
    }
  }

  getMenuPosition(note: Note): { top: number; left: number } {
    const noteLeft = this.getNoteLeft(note);
    const containerEl = this.boardContainerRef?.nativeElement;
    const containerRect = containerEl ? containerEl.getBoundingClientRect() : { top: 0, left: 0 };
    const scrollTop = containerEl?.scrollTop ?? 0;
    const menuTop = containerRect.top + note.posY - scrollTop - 4;
    const menuLeft = containerRect.left + noteLeft;
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

  setHeartColor(note: Note, color: string, event: Event): void {
    event.stopPropagation();
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, heartColor: color } : n);
    this.notesService.update(note.id, { heartColor: color }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  // ── Drag handling ───────────────────────────────────────────────────────────

  startDrag(note: Note, event: MouseEvent | TouchEvent): void {
    this.selectedNoteId = note.id;
    const target = event.target as HTMLElement;

    // Two-finger touch → pinch gesture (resize + rotate)
    if (event instanceof TouchEvent && event.touches.length >= 2) {
      this.dragging = null;
      this.removeDragListeners();
      this.startPinch(note, event);
      return;
    }

    if (
      target.closest('textarea') ||
      target.closest('button') ||
      target.closest('.note-menu') ||
      target.closest('.resize-handle')
    ) {
      return;
    }
    // For text notes, only drag from header
    if (note.type === 'text' && !target.closest('.note-header')) {
      return;
    }
    event.preventDefault();

    this.bringToFront(note);

    const { clientX, clientY } = this.getEventCoords(event);

    this.dragging = {
      noteId: note.id,
      startMouseX: clientX,
      startMouseY: clientY,
      startPosX: note.posX,
      startPosY: note.posY,
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

    // Second finger added mid-drag → transition to pinch
    if (event instanceof TouchEvent && event.touches.length >= 2) {
      const noteId = this.dragging.noteId;
      this.dragging = null;
      this.removeDragListeners();
      const note = this.notes.find(n => n.id === noteId);
      if (note) this.startPinch(note, event);
      return;
    }

    if (event instanceof TouchEvent) event.preventDefault();

    const { clientX, clientY } = this.getEventCoords(event);
    const dx = clientX - this.dragging.startMouseX;
    const dy = clientY - this.dragging.startMouseY;

    const boardEl = this.boardRef?.nativeElement;
    const boardWidth = boardEl ? boardEl.offsetWidth : window.innerWidth;
    const note = this.notes.find(n => n.id === this.dragging!.noteId);
    const w = note ? this.getStickerWidth(note) : NOTE_WIDTH;

    const dxPercent = (dx / (boardWidth - w)) * 100;
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

  // ── Resize handling ─────────────────────────────────────────────────────────

  startResize(note: Note, event: MouseEvent | TouchEvent): void {
    this.selectedNoteId = note.id;
    event.stopPropagation();
    event.preventDefault();

    const { clientX, clientY } = this.getEventCoords(event);
    const w = note.type === 'text' ? (note.width ?? NOTE_WIDTH) : (note.width ?? (note.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_WIDTH));
    const h = note.height ?? (note.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_HEIGHT);

    this.resizing = {
      noteId: note.id,
      startMouseX: clientX,
      startMouseY: clientY,
      startWidth: w,
      startHeight: h,
      aspectRatio: note.type === 'image' ? h / w : null,
    };

    this.zone.runOutsideAngular(() => {
      window.addEventListener('mousemove', this.onResizeMove);
      window.addEventListener('touchmove', this.onResizeMove, { passive: false });
      window.addEventListener('mouseup', this.onResizeEnd);
      window.addEventListener('touchend', this.onResizeEnd);
    });
  }

  private onResizeMove = (event: MouseEvent | TouchEvent): void => {
    if (!this.resizing) return;
    if (event instanceof TouchEvent) event.preventDefault();

    const { clientX, clientY } = this.getEventCoords(event);
    const dx = clientX - this.resizing.startMouseX;
    const dy = clientY - this.resizing.startMouseY;

    const newWidth = Math.max(60, this.resizing.startWidth + dx);
    const newHeight = this.resizing.aspectRatio !== null
      ? newWidth * this.resizing.aspectRatio
      : Math.max(60, this.resizing.startHeight + dy);

    this.zone.run(() => {
      this.notes = this.notes.map(n =>
        n.id === this.resizing!.noteId ? { ...n, width: newWidth, height: newHeight } : n
      );
      this.cdr.markForCheck();
    });
  };

  private onResizeEnd = (): void => {
    if (!this.resizing) return;
    const { noteId } = this.resizing;
    this.resizing = null;
    this.removeResizeListeners();

    const note = this.notes.find(n => n.id === noteId);
    if (note) {
      this.notesService.update(noteId, { width: note.width!, height: note.height! }).subscribe({ error: () => {} });
    }
  };

  private removeResizeListeners(): void {
    window.removeEventListener('mousemove', this.onResizeMove);
    window.removeEventListener('touchmove', this.onResizeMove);
    window.removeEventListener('mouseup', this.onResizeEnd);
    window.removeEventListener('touchend', this.onResizeEnd);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

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

  selectNoteById(noteId: number): void {
    this.selectedNoteId = noteId;
    this.cdr.markForCheck();
  }

  toggleBgPanel(event: Event): void {
    event.stopPropagation();
    this.showBgPanel = !this.showBgPanel;
    this.cdr.markForCheck();
  }

  setBgPattern(i: number, event: Event): void {
    event.stopPropagation();
    this.boardBgIndex = i;
    this.boardBgColor = null;
    localStorage.setItem('board-bg', JSON.stringify({ index: i, color: null }));
    this.cdr.markForCheck();
  }

  setBgColor(color: string, event: Event): void {
    event.stopPropagation();
    this.boardBgColor = color;
    localStorage.setItem('board-bg', JSON.stringify({ index: this.boardBgIndex, color }));
    this.cdr.markForCheck();
  }

  get currentBgDef() { return this.BOARD_BG_DEFS[this.boardBgIndex] ?? this.BOARD_BG_DEFS[0]; }

  get boardBgStyle(): Record<string, string> {
    const def = this.currentBgDef;
    const c = this.boardBgColor ?? def.defaultColor;
    return { 'background-color': def.bgColor, 'background-image': def.getPattern(c), 'background-size': def.bgSize };
  }

  rotateNote(note: Note, delta: number, event: Event): void {
    event.stopPropagation();
    const next = (note.rotation ?? 0) + delta;
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, rotation: next } : n);
    this.notesService.update(note.id, { rotation: next }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  resetRotation(note: Note, event: Event): void {
    event.stopPropagation();
    this.notes = this.notes.map(n => n.id === note.id ? { ...n, rotation: 0 } : n);
    this.notesService.update(note.id, { rotation: 0 }).subscribe({ error: () => {} });
    this.cdr.detectChanges();
  }

  startRotate(note: Note, event: MouseEvent | TouchEvent): void {
    event.stopPropagation();
    event.preventDefault();
    this.selectedNoteId = note.id;
    const { clientX, clientY } = this.getEventCoords(event);
    const noteLeft = this.getNoteLeft(note);
    const noteWidth = this.getStickerWidth(note);
    const noteHeight = note.type === 'text' ? (note.height ?? 180) : (note.height ?? (note.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_HEIGHT));
    const containerEl = this.boardContainerRef?.nativeElement;
    const rect = containerEl ? containerEl.getBoundingClientRect() : { top: 0, left: 0 };
    const scrollTop = containerEl?.scrollTop ?? 0;
    const centerX = rect.left + noteLeft + noteWidth / 2;
    const centerY = rect.top + note.posY + noteHeight / 2 - scrollTop;
    this.rotating = {
      noteId: note.id, centerX, centerY,
      startAngle: Math.atan2(clientY - centerY, clientX - centerX) * (180 / Math.PI),
      startRotation: note.rotation ?? 0,
    };
    this.zone.runOutsideAngular(() => {
      window.addEventListener('mousemove', this.onRotateMove);
      window.addEventListener('touchmove', this.onRotateMove, { passive: false });
      window.addEventListener('mouseup', this.onRotateEnd);
      window.addEventListener('touchend', this.onRotateEnd);
    });
  }

  private onRotateMove = (event: MouseEvent | TouchEvent): void => {
    if (!this.rotating) return;
    if (event instanceof TouchEvent) event.preventDefault();
    const { clientX, clientY } = this.getEventCoords(event);
    const cur = Math.atan2(clientY - this.rotating.centerY, clientX - this.rotating.centerX) * (180 / Math.PI);
    const newRot = this.rotating.startRotation + (cur - this.rotating.startAngle);
    this.zone.run(() => {
      this.notes = this.notes.map(n => n.id === this.rotating!.noteId ? { ...n, rotation: newRot } : n);
      this.cdr.markForCheck();
    });
  };

  private onRotateEnd = (): void => {
    if (!this.rotating) return;
    const { noteId } = this.rotating;
    this.rotating = null;
    this.removeRotateListeners();
    const note = this.notes.find(n => n.id === noteId);
    if (note) this.notesService.update(noteId, { rotation: note.rotation! }).subscribe({ error: () => {} });
  };

  private removeRotateListeners(): void {
    window.removeEventListener('mousemove', this.onRotateMove);
    window.removeEventListener('touchmove', this.onRotateMove);
    window.removeEventListener('mouseup', this.onRotateEnd);
    window.removeEventListener('touchend', this.onRotateEnd);
  }

  // ── Pinch gesture (two-finger resize + rotate) ───────────────────────────────

  private startPinch(note: Note, event: TouchEvent): void {
    event.preventDefault();
    event.stopPropagation();

    const t0 = event.touches[0];
    const t1 = event.touches[1];
    const dx = t1.clientX - t0.clientX;
    const dy = t1.clientY - t0.clientY;

    const w = note.type === 'text'
      ? (note.width ?? NOTE_WIDTH)
      : (note.width ?? (note.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_WIDTH));
    const h = note.height ?? (note.type === 'heart' ? DEFAULT_HEART_SIZE : DEFAULT_IMAGE_HEIGHT);

    this.pinching = {
      noteId: note.id,
      startDist: Math.sqrt(dx * dx + dy * dy),
      startAngle: Math.atan2(dy, dx) * (180 / Math.PI),
      startWidth: w,
      startHeight: h,
      startRotation: note.rotation ?? 0,
      aspectRatio: note.type === 'image' ? h / w : null,
    };

    this.zone.runOutsideAngular(() => {
      window.addEventListener('touchmove', this.onPinchMove, { passive: false });
      window.addEventListener('touchend', this.onPinchEnd);
    });
  }

  private onPinchMove = (event: TouchEvent): void => {
    if (!this.pinching || event.touches.length < 2) return;
    event.preventDefault();

    const t0 = event.touches[0];
    const t1 = event.touches[1];
    const dx = t1.clientX - t0.clientX;
    const dy = t1.clientY - t0.clientY;

    const dist = Math.sqrt(dx * dx + dy * dy);
    const angle = Math.atan2(dy, dx) * (180 / Math.PI);
    const scale = dist / this.pinching.startDist;
    const deltaAngle = angle - this.pinching.startAngle;

    const newWidth = Math.max(60, this.pinching.startWidth * scale);
    const newHeight = this.pinching.aspectRatio !== null
      ? newWidth * this.pinching.aspectRatio
      : Math.max(60, this.pinching.startHeight * scale);
    const newRotation = this.pinching.startRotation + deltaAngle;

    this.zone.run(() => {
      this.notes = this.notes.map(n =>
        n.id === this.pinching!.noteId
          ? { ...n, width: newWidth, height: newHeight, rotation: newRotation }
          : n
      );
      this.cdr.markForCheck();
    });
  };

  private onPinchEnd = (event: TouchEvent): void => {
    if (event.touches.length >= 2) return; // still pinching
    if (!this.pinching) return;
    const { noteId } = this.pinching;
    this.pinching = null;
    this.removePinchListeners();

    const note = this.notes.find(n => n.id === noteId);
    if (note) {
      this.notesService.update(noteId, {
        width: note.width!,
        height: note.height!,
        rotation: note.rotation!,
      }).subscribe({ error: () => {} });
    }
  };

  private removePinchListeners(): void {
    window.removeEventListener('touchmove', this.onPinchMove);
    window.removeEventListener('touchend', this.onPinchEnd);
  }
}
