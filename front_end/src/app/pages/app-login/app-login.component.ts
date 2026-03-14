import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AppAuthService } from '../../services/app-auth.service';
import { HouseholdStateService } from '../../services/household-state.service';

@Component({
  selector: 'app-app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app-login.component.html',
  styleUrls: ['./app-login.component.css']
})
export class AppLoginComponent {
  username = '';
  password = '';
  error = '';
  noHousehold = false;
  loading = false;
  showPassword = false;

  constructor(
    private appAuthService: AppAuthService,
    private householdStateService: HouseholdStateService,
    private router: Router
  ) {}

  togglePassword(): void {
    this.showPassword = !this.showPassword;
  }

  onSubmit(): void {
    if (!this.username || !this.password) {
      this.error = 'Please enter your username and password';
      return;
    }

    this.loading = true;
    this.error = '';
    this.noHousehold = false;

    this.appAuthService.signIn(this.username, this.password).subscribe({
      next: (response) => {
        const user = response.user;
        if (!user.households || user.households.length === 0) {
          this.noHousehold = true;
          this.loading = false;
          return;
        }
        this.householdStateService.initFromStorage();
        this.router.navigate(['/app/expenses']);
      },
      error: (err) => {
        console.error(err);
        this.error = err?.error?.message || 'Invalid username or password';
        this.loading = false;
      }
    });
  }
}
