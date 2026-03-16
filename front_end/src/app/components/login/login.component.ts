import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { AppAuthService } from '../../services/app-auth.service';
import { LoggerService } from '../../services/logger.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css']
})
export class LoginComponent {
  username = '';
  password = '';
  error = '';
  loading = false;

  constructor(
    private authService: AuthService,
    private appAuthService: AppAuthService,
    private router: Router,
    private logger: LoggerService
  ) { }

  ngOnInit(): void {
    this.logger.logComponentInit('LoginComponent');
  }

  ngOnDestroy(): void {
    this.logger.logComponentDestroy('LoginComponent');
  }

  onSubmit(): void {
    if (!this.username || !this.password) {
      this.error = 'Please enter username and password';
      return;
    }

    this.loading = true;
    this.error = '';

    // Try management system login first
    this.authService.login(this.username, this.password).subscribe({
      next: () => {
        this.logger.info('LOGIN_SUCCESS', 'Management user logged in', { username: this.username });
        this.router.navigate(['/home']);
      },
      error: () => {
        // Fall back to app user login
        this.appAuthService.signIn(this.username, this.password).subscribe({
          next: (response) => {
            this.logger.info('LOGIN_SUCCESS', 'App user logged in', { username: this.username });
            const user = response.user;
            if (!user.households || user.households.length === 0) {
              this.error = 'No household assigned to this account.';
              this.loading = false;
              return;
            }
            this.router.navigate(['/app']);
          },
          error: (err) => {
            this.logger.warn('LOGIN_FAILED', 'Login attempt failed', { username: this.username, error: err.message });
            this.error = 'Invalid username or password';
            this.loading = false;
          }
        });
      }
    });
  }
}