import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { Subscription } from 'rxjs';
import { AppAuthService, AppUser } from '../../services/app-auth.service';
import { HouseholdStateService, SelectedHousehold } from '../../services/household-state.service';

@Component({
  selector: 'app-app-layout',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './app-layout.component.html',
  styleUrls: ['./app-layout.component.css']
})
export class AppLayoutComponent implements OnInit, OnDestroy {
  currentUser: AppUser | null = null;
  selectedHousehold: SelectedHousehold | null = null;
  showHouseholdDropdown = false;

  private userSub!: Subscription;
  private householdSub!: Subscription;

  constructor(
    private appAuthService: AppAuthService,
    private householdStateService: HouseholdStateService
  ) {}

  ngOnInit(): void {
    this.householdStateService.initFromStorage();

    this.userSub = this.appAuthService.currentUser$.subscribe(user => {
      this.currentUser = user;
      if (user && !this.selectedHousehold) {
        this.householdStateService.initFromStorage();
      }
    });

    this.householdSub = this.householdStateService.selectedHousehold$.subscribe(household => {
      this.selectedHousehold = household;
    });

    if (!this.currentUser) {
      this.appAuthService.loadCurrentUser();
    }
  }

  ngOnDestroy(): void {
    this.userSub?.unsubscribe();
    this.householdSub?.unsubscribe();
  }

  get hasMultipleHouseholds(): boolean {
    return (this.currentUser?.households?.length ?? 0) > 1;
  }

  toggleDropdown(): void {
    this.showHouseholdDropdown = !this.showHouseholdDropdown;
  }

  selectHousehold(h: { householdId: number; householdName: string; role: string }): void {
    this.householdStateService.setHousehold({ householdId: h.householdId, householdName: h.householdName });
    this.showHouseholdDropdown = false;
  }

  signOut(): void {
    this.appAuthService.signOut();
  }
}
