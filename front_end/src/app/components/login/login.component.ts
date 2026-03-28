import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
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
    private router: Router,
    private logger: LoggerService
  ) { }

  ngOnInit(): void {
    console.log("AAADADAWDADAWDWDAWD");
    this.logger.logComponentInit('LoginComponent');
  }

  ngOnDestroy(): void {
    this.logger.logComponentDestroy('LoginComponent');
  }

  onSubmit(): void {
    console.error("Hi !! Over HERE!");
    if (!this.username || !this.password) {
      this.error = 'Please enter username and password';
      return;
    }

    this.loading = true;
    this.error = '';

    this.authService.login(this.username, this.password).subscribe({
      next: () => {
        this.logger.info('LOGIN_SUCCESS', 'Management user logged in', { username: this.username });
        this.router.navigate(['/home']);
      },
      error: (err) => {
        this.logger.warn('LOGIN_FAILED', 'Login attempt failed', { username: this.username, error: err.message });
        this.error = 'Invalid username or password';
        this.loading = false;
      }
    });
  }
}