# Simple Admin Setup for Cal.com

## Quick Start (5 Minutes)

Cal.com already has everything you need! No complex changes required.

## Step 1: Create Admin User

```sql
-- Connect to your database and run:
UPDATE "User" 
SET role = 'ADMIN' 
WHERE email = 'your-admin@example.com';
```

## Step 2: Use Existing Admin Features

1. Login as the admin user
2. Navigate to: `/settings/admin/impersonation`
3. Enter any username to impersonate
4. You're now viewing/acting as that user!

### What Admins Can Do:
- ✅ View any user's calendar
- ✅ Create bookings for them
- ✅ Manage their event types
- ✅ Edit their availability
- ✅ View their existing bookings

## Step 3: Optional - Simple Admin Dashboard

If you want a quick list of all users to impersonate, create this single file:

### File: `/apps/web/app/admin/simple-dashboard/page.tsx`

```tsx
"use client";

import { useState, useEffect } from "react";
import { useSession, signIn } from "next-auth/react";
import { Button } from "@calcom/ui";

export default function SimpleAdminDashboard() {
  const { data: session } = useSession();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch all users
    fetch("/api/trpc/viewer.members.list")
      .then(res => res.json())
      .then(data => {
        setUsers(data.result?.data || []);
        setLoading(false);
      });
  }, []);

  // Check if user is admin
  if (!session?.user?.role || session.user.role !== "ADMIN") {
    return <div className="p-8">Access denied. Admin only.</div>;
  }

  const handleImpersonate = (username: string) => {
    // Use Cal.com's existing impersonation
    signIn("impersonation-auth", { 
      username,
      callbackUrl: "/" 
    });
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-6">Admin Dashboard</h1>
      
      <div className="bg-white rounded-lg shadow">
        <table className="min-w-full">
          <thead>
            <tr className="border-b">
              <th className="px-6 py-3 text-left">User</th>
              <th className="px-6 py-3 text-left">Email</th>
              <th className="px-6 py-3 text-left">Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user: any) => (
              <tr key={user.id} className="border-b">
                <td className="px-6 py-4">{user.name}</td>
                <td className="px-6 py-4">{user.email}</td>
                <td className="px-6 py-4">
                  <Button
                    size="sm"
                    onClick={() => handleImpersonate(user.username)}
                  >
                    View as User
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      {loading && <div>Loading users...</div>}
    </div>
  );
}
```

## That's It! 🎉

You now have admin functionality with:
- **Zero database changes** (except setting role = 'ADMIN')
- **Zero API changes** 
- **One optional UI file** for convenience

## How It Works

Cal.com's impersonation system (`/packages/features/ee/impersonation/`) already:
1. Checks if you're an ADMIN
2. Lets you act as any user
3. Logs the impersonation for audit
4. Shows a banner so you know you're impersonating
5. Lets you return to your admin account

## Quick Test

1. Make yourself admin:
   ```bash
   yarn prisma studio
   # Find your user, change role to ADMIN
   ```

2. Login and go to:
   ```
   http://localhost:3000/settings/admin/impersonation
   ```

3. Enter any username and click impersonate

4. You're now viewing their calendar and can book for them!

## Common Tasks as Admin

### View Someone's Calendar
1. Impersonate them
2. Go to `/bookings`
3. See all their bookings

### Create Appointment for Someone
1. Impersonate them
2. Go to their booking page
3. Book an appointment (it will be under their name)

### Manage Someone's Availability
1. Impersonate them
2. Go to `/availability`
3. Edit their schedules

### Stop Impersonating
- Click "Stop Impersonating" in the yellow banner at the top
- Or logout and login again

## Security Notes

- All impersonations are logged in the `Impersonations` table
- Only users with role='ADMIN' can impersonate
- You can disable impersonation for specific users by setting `disableImpersonation = true`

## FAQ

**Q: Can I see multiple calendars at once?**
A: No, but you can open multiple browser tabs and impersonate different users in each.

**Q: Is this secure?**
A: Yes, Cal.com's impersonation has audit logging and role checks built-in.

**Q: Can I limit what admins can do?**
A: The existing system is all-or-nothing. Admins can do everything the user can do.

**Q: Do I need the enterprise edition?**
A: Check if impersonation is marked as an EE feature in your version. If so, you'll need the appropriate license.

## Want More Features?

If you need:
- Bulk operations
- View multiple calendars simultaneously  
- Create bookings without impersonation
- Custom admin permissions

Then you'll need custom development. But for basic "admin can manage users" - the above solution works perfectly!