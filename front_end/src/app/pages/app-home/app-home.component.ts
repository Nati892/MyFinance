import {
  Component,
  OnInit,
  OnDestroy,
  ChangeDetectorRef,
  ChangeDetectionStrategy,
  ElementRef,
  ViewChild,
  NgZone,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';

import { HouseholdStateService } from '../../services/household-state.service';
import { AppAuthService } from '../../services/app-auth.service';
import { NotesService, Note } from '../../services/notes.service';
import { SocketService } from '../../services/socket.service';

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

  householdId: number | null = null;
  notes: Note[] = [];
  loading = true;

  // Max zIndex currently in use
  private maxZ = 1;

  // Drag state
  private dragging: {
    noteId: number;
    startMouseX: number;
    startMouseY: number;
    startPosX: number;
    startPosY: number;
  } | null = null;

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
          this.notes = [...this.notes, note];
          this.maxZ = Math.max(this.maxZ, note.zIndex);
          this.cdr.markForCheck();
        }
      })
    );

    this.subs.add(
      this.socketService.noteUpdated$.subscribe(updated => {
        this.notes = this.notes.map(n => n.id === updated.id ? updated : n);
        this.maxZ = Math.max(this.maxZ, updated.zIndex);
        this.cdr.markForCheck();
      })
    );

    this.subs.add(
      this.socketService.noteDeleted$.subscribe(id => {
        this.notes = this.notes.filter(n => n.id !== id);
        this.cdr.markForCheck();
      })
    );
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
    this.socketService.disconnect();
    this.removeDragListeners();
  }

  private connectSocket(): void {
    const token = this.appAuthService.getToken();
    if (token && this.householdId) {
      this.socketService.connect(this.householdId, token);
    }
  }

  loadNotes(): void {
    if (!this.householdId) return;
    this.loading = true;
    this.cdr.markForCheck();

    this.notesService.list(this.householdId).subscribe({
      next: res => {
        this.notes = res.notes ?? [];
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

    // Place new note near center of current board viewport
    const board = this.boardRef?.nativeElement;
    const scrollLeft = board?.scrollLeft ?? 0;
    const scrollTop = board?.scrollTop ?? 0;
    const clientW = board?.clientWidth ?? 300;
    const clientH = board?.clientHeight ?? 400;

    const posX = scrollLeft + clientW / 2 - 100 + Math.random() * 40 - 20;
    const posY = scrollTop + clientH / 2 - 80 + Math.random() * 40 - 20;

    this.notesService.create({
      content: '',
      posX: Math.max(0, posX),
      posY: Math.max(0, posY),
      zIndex: ++this.maxZ,
      householdId: this.householdId,
    }).subscribe({
      next: res => {
        // Socket event will add it; but also add locally to avoid delay
        if (!this.notes.find(n => n.id === res.note.id)) {
          this.notes = [...this.notes, res.note];
          this.cdr.markForCheck();
        }
      },
      error: () => alert('Failed to create note.'),
    });
  }

  deleteNote(note: Note, event: Event): void {
    event.stopPropagation();
    this.notesService.delete(note.id).subscribe({
      error: () => alert('Failed to delete note.'),
    });
    // Optimistic remove
    this.notes = this.notes.filter(n => n.id !== note.id);
    this.cdr.markForCheck();
  }

  onNoteContentChange(note: Note, content: string): void {
    this.notesService.update(note.id, { content }).subscribe({ error: () => {} });
  }

  // ── Drag handling ────────────────────────────────────────────────────────────

  startDrag(note: Note, event: MouseEvent | TouchEvent): void {
    event.preventDefault();

    // Bring to front
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
    if (event instanceof TouchEvent) event.preventDefault();

    const { clientX, clientY } = this.getEventCoords(event);
    const dx = clientX - this.dragging.startMouseX;
    const dy = clientY - this.dragging.startMouseY;

    const newX = Math.max(0, this.dragging.startPosX + dx);
    const newY = Math.max(0, this.dragging.startPosY + dy);

    this.zone.run(() => {
      this.notes = this.notes.map(n =>
        n.id === this.dragging!.noteId ? { ...n, posX: newX, posY: newY } : n
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

  getNoteColor(note: Note): string {
    // Cycle through a set of warm note colors based on note id
    const colors = ['#fff9c4', '#f3e5f5', '#e3f2fd', '#e8f5e9', '#fff3e0', '#fce4ec'];
    return colors[note.id % colors.length];
  }
}
