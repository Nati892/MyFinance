import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { AppAuthService } from '../services/app-auth.service';

@Injectable({ providedIn: 'root' })
export class AppAuthGuard implements CanActivate {
  constructor(
    private appAuthService: AppAuthService,
    private router: Router
  ) {}

  canActivate(): Observable<boolean> {
    return this.appAuthService.checkAndRefresh().pipe(
      tap(isValid => {
        if (!isValid) {
          this.router.navigate(['/app/login']);
        }
      })
    );
  }
}
