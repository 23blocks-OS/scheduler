# Admin Mode & Platform User Sync Implementation Plan

## Executive Summary

This document outlines the implementation plan for adding administrative capabilities to Cal.com, enabling platform administrators to:
- View all users' calendars
- Schedule appointments on behalf of any user
- Synchronize users from an external platform
- Manage user accounts and settings centrally

The implementation leverages Cal.com's existing impersonation system while adding proper admin controls and platform synchronization capabilities.

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [Implementation Requirements](#implementation-requirements)
3. [Technical Implementation](#technical-implementation)
4. [API Specifications](#api-specifications)
5. [Security & Compliance](#security--compliance)
6. [Implementation Timeline](#implementation-timeline)
7. [Testing Strategy](#testing-strategy)
8. [Deployment Guide](#deployment-guide)

## Current Architecture Analysis

### Existing Features
Cal.com already provides several features that can be extended for admin mode:

1. **Role-Based Access Control (RBAC)**
   - Current roles: `USER`, `ADMIN`
   - Located in: `/packages/prisma/schema.prisma`
   - Enum: `UserPermissionRole`

2. **Impersonation System**
   - Allows admins to act as other users
   - Implementation: `/packages/features/ee/impersonation/`
   - Audit trail via `Impersonations` table

3. **Organization Structure**
   - Teams with role-based permissions
   - Member roles: `MEMBER`, `ADMIN`, `OWNER`
   - Custom roles support via `Role` and `RolePermission` tables

4. **API Infrastructure**
   - RESTful API v1 and v2
   - tRPC for internal APIs
   - API key authentication system

### Current Limitations
- No bulk user management APIs
- Limited admin visibility into all users' calendars
- No platform synchronization capabilities
- Admin actions require impersonation

## Implementation Requirements

### Functional Requirements

#### Admin Capabilities
1. **User Management**
   - View all users in the system
   - Create/update/delete user accounts
   - Manage user permissions and roles
   - Bulk operations support

2. **Calendar Management**
   - View all users' calendars simultaneously
   - Check availability across multiple users
   - Create bookings on behalf of users
   - Manage event types for users

3. **Platform Synchronization**
   - Automatic user creation from external platform
   - Real-time sync of user data
   - Webhook notifications for changes
   - Bulk import/export capabilities

4. **Audit & Compliance**
   - Complete audit trail of admin actions
   - GDPR-compliant data handling
   - Export audit logs
   - Role-based access restrictions

### Non-Functional Requirements
- Performance: Handle 10,000+ users
- Availability: 99.9% uptime for sync operations
- Security: Encrypted API communications
- Scalability: Support for multiple platform integrations

## Technical Implementation

### 1. Database Schema Updates

#### New Tables and Fields

```sql
-- Update User table with platform sync fields
ALTER TABLE "User" 
ADD COLUMN "externalPlatformId" VARCHAR(255) UNIQUE,
ADD COLUMN "syncedFromPlatform" BOOLEAN DEFAULT false,
ADD COLUMN "lastSyncedAt" TIMESTAMP,
ADD COLUMN "platformMetadata" JSONB,
ADD COLUMN "managedByAdmin" BOOLEAN DEFAULT false,
ADD COLUMN "platformSource" VARCHAR(100);

-- Create index for performance
CREATE INDEX idx_user_external_platform_id ON "User"("externalPlatformId");
CREATE INDEX idx_user_synced_from_platform ON "User"("syncedFromPlatform");

-- Admin audit log table
CREATE TABLE "AdminAuditLog" (
  "id" SERIAL PRIMARY KEY,
  "adminId" INTEGER NOT NULL REFERENCES "User"("id"),
  "targetUserId" INTEGER REFERENCES "User"("id"),
  "action" VARCHAR(50) NOT NULL,
  "resourceType" VARCHAR(50),
  "resourceId" INTEGER,
  "metadata" JSONB,
  "ipAddress" VARCHAR(45),
  "userAgent" TEXT,
  "createdAt" TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_admin_id ON "AdminAuditLog"("adminId");
CREATE INDEX idx_audit_target_user_id ON "AdminAuditLog"("targetUserId");
CREATE INDEX idx_audit_created_at ON "AdminAuditLog"("createdAt");

-- Platform sync status table
CREATE TABLE "PlatformSyncStatus" (
  "id" SERIAL PRIMARY KEY,
  "platformId" VARCHAR(100) NOT NULL,
  "lastSyncAt" TIMESTAMP,
  "syncType" VARCHAR(50),
  "status" VARCHAR(20),
  "recordsProcessed" INTEGER,
  "recordsFailed" INTEGER,
  "errorDetails" JSONB,
  "createdAt" TIMESTAMP DEFAULT NOW(),
  "updatedAt" TIMESTAMP DEFAULT NOW()
);

-- Platform API keys table
CREATE TABLE "PlatformApiKey" (
  "id" SERIAL PRIMARY KEY,
  "key" VARCHAR(255) UNIQUE NOT NULL,
  "platformName" VARCHAR(100) NOT NULL,
  "permissions" JSONB,
  "isActive" BOOLEAN DEFAULT true,
  "lastUsedAt" TIMESTAMP,
  "createdAt" TIMESTAMP DEFAULT NOW(),
  "expiresAt" TIMESTAMP
);
```

#### Prisma Schema Updates

```prisma
// Add to /packages/prisma/schema.prisma

enum UserPermissionRole {
  USER
  ADMIN
  PLATFORM_ADMIN  // New role for platform administrators
  SUPER_ADMIN     // New role for system-wide administration
}

model User {
  // ... existing fields
  externalPlatformId String?    @unique
  syncedFromPlatform Boolean    @default(false)
  lastSyncedAt       DateTime?
  platformMetadata   Json?
  managedByAdmin     Boolean    @default(false)
  platformSource     String?
  
  // Relations
  adminAuditLogs     AdminAuditLog[] @relation("AdminUser")
  targetAuditLogs    AdminAuditLog[] @relation("TargetUser")
  
  @@index([externalPlatformId])
  @@index([syncedFromPlatform])
}

model AdminAuditLog {
  id           Int      @id @default(autoincrement())
  adminId      Int
  admin        User     @relation("AdminUser", fields: [adminId], references: [id])
  targetUserId Int?
  targetUser   User?    @relation("TargetUser", fields: [targetUserId], references: [id])
  action       String
  resourceType String?
  resourceId   Int?
  metadata     Json?
  ipAddress    String?
  userAgent    String?
  createdAt    DateTime @default(now())
  
  @@index([adminId])
  @@index([targetUserId])
  @@index([createdAt])
}

model PlatformSyncStatus {
  id               Int      @id @default(autoincrement())
  platformId       String
  lastSyncAt       DateTime?
  syncType         String?
  status           String?
  recordsProcessed Int?
  recordsFailed    Int?
  errorDetails     Json?
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt
}

model PlatformApiKey {
  id           Int       @id @default(autoincrement())
  key          String    @unique
  platformName String
  permissions  Json?
  isActive     Boolean   @default(true)
  lastUsedAt   DateTime?
  createdAt    DateTime  @default(now())
  expiresAt    DateTime?
}
```

### 2. API Layer Implementation

#### Directory Structure
```
/apps/api/v2/src/modules/
├── platform-sync/
│   ├── controllers/
│   │   ├── platform-sync.controller.ts
│   │   └── platform-sync.controller.spec.ts
│   ├── services/
│   │   ├── platform-sync.service.ts
│   │   ├── user-sync.service.ts
│   │   └── webhook.service.ts
│   ├── dto/
│   │   ├── create-platform-user.dto.ts
│   │   ├── update-platform-user.dto.ts
│   │   └── sync-status.dto.ts
│   ├── guards/
│   │   └── platform-api-key.guard.ts
│   └── platform-sync.module.ts
├── admin-operations/
│   ├── controllers/
│   │   ├── admin-users.controller.ts
│   │   ├── admin-bookings.controller.ts
│   │   └── admin-calendars.controller.ts
│   ├── services/
│   │   ├── admin-operations.service.ts
│   │   ├── audit-log.service.ts
│   │   └── bulk-operations.service.ts
│   └── admin-operations.module.ts
```

#### Platform Sync Controller

```typescript
// /apps/api/v2/src/modules/platform-sync/controllers/platform-sync.controller.ts

import { Controller, Post, Get, Delete, Put, Body, Param, UseGuards, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiSecurity } from '@nestjs/swagger';
import { PlatformApiKeyGuard } from '../guards/platform-api-key.guard';
import { PlatformSyncService } from '../services/platform-sync.service';
import { CreatePlatformUserDto, UpdatePlatformUserDto, BulkSyncDto } from '../dto';
import { AuditLog } from '../../common/decorators/audit-log.decorator';

@ApiTags('Platform Sync')
@Controller('api/v2/platform-sync')
@UseGuards(PlatformApiKeyGuard)
@ApiSecurity('platform-api-key')
export class PlatformSyncController {
  constructor(private readonly syncService: PlatformSyncService) {}

  @Post('users')
  @ApiOperation({ summary: 'Create or update a user from platform' })
  @AuditLog('PLATFORM_USER_SYNC')
  async syncUser(@Body() userData: CreatePlatformUserDto) {
    return this.syncService.syncUser(userData);
  }

  @Post('users/bulk')
  @ApiOperation({ summary: 'Bulk sync multiple users' })
  @AuditLog('PLATFORM_BULK_SYNC')
  async bulkSyncUsers(@Body() data: BulkSyncDto) {
    return this.syncService.bulkSync(data.users);
  }

  @Get('users/:platformId')
  @ApiOperation({ summary: 'Get user by platform ID' })
  async getUserByPlatformId(@Param('platformId') platformId: string) {
    return this.syncService.getUserByPlatformId(platformId);
  }

  @Put('users/:platformId')
  @ApiOperation({ summary: 'Update user by platform ID' })
  @AuditLog('PLATFORM_USER_UPDATE')
  async updateUser(
    @Param('platformId') platformId: string,
    @Body() userData: UpdatePlatformUserDto
  ) {
    return this.syncService.updateUser(platformId, userData);
  }

  @Delete('users/:platformId')
  @ApiOperation({ summary: 'Deactivate user by platform ID' })
  @AuditLog('PLATFORM_USER_DEACTIVATE')
  async deactivateUser(@Param('platformId') platformId: string) {
    return this.syncService.deactivateUser(platformId);
  }

  @Get('sync-status')
  @ApiOperation({ summary: 'Get sync status and statistics' })
  async getSyncStatus(@Query('from') from?: string, @Query('to') to?: string) {
    return this.syncService.getSyncStatus(from, to);
  }

  @Post('webhooks/register')
  @ApiOperation({ summary: 'Register webhook endpoints' })
  async registerWebhooks(@Body() webhookConfig: any) {
    return this.syncService.registerWebhooks(webhookConfig);
  }
}
```

#### Platform Sync Service

```typescript
// /apps/api/v2/src/modules/platform-sync/services/platform-sync.service.ts

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@calcom/prisma';
import { UserService } from '../../users/services/user.service';
import { WebhookService } from './webhook.service';
import { AuditLogService } from '../../admin-operations/services/audit-log.service';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class PlatformSyncService {
  private readonly logger = new Logger(PlatformSyncService.name);

  constructor(
    private prisma: PrismaService,
    private userService: UserService,
    private webhookService: WebhookService,
    private auditLog: AuditLogService
  ) {}

  async syncUser(userData: CreatePlatformUserDto) {
    const { externalId, email, name, username, metadata } = userData;
    
    try {
      // Check if user exists
      let user = await this.prisma.user.findUnique({
        where: { externalPlatformId: externalId }
      });

      if (user) {
        // Update existing user
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: {
            email,
            name,
            username,
            platformMetadata: metadata,
            lastSyncedAt: new Date(),
          }
        });
        
        await this.auditLog.log({
          action: 'USER_UPDATED',
          targetUserId: user.id,
          metadata: { source: 'platform_sync', externalId }
        });
      } else {
        // Create new user
        const tempPassword = await bcrypt.hash(Math.random().toString(36), 10);
        
        user = await this.prisma.user.create({
          data: {
            email,
            name,
            username: username || email.split('@')[0],
            externalPlatformId: externalId,
            syncedFromPlatform: true,
            platformMetadata: metadata,
            managedByAdmin: true,
            lastSyncedAt: new Date(),
            password: {
              create: {
                hash: tempPassword
              }
            }
          }
        });

        // Create default schedule
        await this.createDefaultSchedule(user.id);
        
        await this.auditLog.log({
          action: 'USER_CREATED',
          targetUserId: user.id,
          metadata: { source: 'platform_sync', externalId }
        });
      }

      // Notify via webhook
      await this.webhookService.notify('user.synced', {
        userId: user.id,
        externalId,
        action: user ? 'updated' : 'created'
      });

      return {
        success: true,
        userId: user.id,
        externalId: user.externalPlatformId,
        message: user ? 'User updated successfully' : 'User created successfully'
      };
    } catch (error) {
      this.logger.error(`Failed to sync user ${externalId}:`, error);
      throw error;
    }
  }

  async bulkSync(users: CreatePlatformUserDto[]) {
    const results = {
      successful: [],
      failed: [],
      total: users.length
    };

    for (const userData of users) {
      try {
        const result = await this.syncUser(userData);
        results.successful.push(result);
      } catch (error) {
        results.failed.push({
          externalId: userData.externalId,
          error: error.message
        });
      }
    }

    // Update sync status
    await this.prisma.platformSyncStatus.create({
      data: {
        platformId: 'default',
        lastSyncAt: new Date(),
        syncType: 'BULK_USER_SYNC',
        status: 'COMPLETED',
        recordsProcessed: results.successful.length,
        recordsFailed: results.failed.length,
        errorDetails: results.failed.length > 0 ? results.failed : null
      }
    });

    return results;
  }

  async getUserByPlatformId(platformId: string) {
    const user = await this.prisma.user.findUnique({
      where: { externalPlatformId: platformId },
      include: {
        eventTypes: true,
        schedules: true,
        credentials: true,
        teams: {
          include: {
            team: true
          }
        }
      }
    });

    if (!user) {
      throw new Error(`User with platform ID ${platformId} not found`);
    }

    return user;
  }

  async updateUser(platformId: string, userData: UpdatePlatformUserDto) {
    const user = await this.prisma.user.update({
      where: { externalPlatformId: platformId },
      data: {
        ...userData,
        lastSyncedAt: new Date()
      }
    });

    await this.auditLog.log({
      action: 'USER_UPDATED_VIA_API',
      targetUserId: user.id,
      metadata: { updates: userData }
    });

    return user;
  }

  async deactivateUser(platformId: string) {
    const user = await this.prisma.user.update({
      where: { externalPlatformId: platformId },
      data: {
        // Cal.com doesn't have a direct 'active' field, so we'll use a workaround
        // Option 1: Set a flag in metadata
        platformMetadata: {
          deactivated: true,
          deactivatedAt: new Date()
        }
      }
    });

    // Cancel all future bookings
    await this.prisma.booking.updateMany({
      where: {
        userId: user.id,
        startTime: { gte: new Date() },
        status: { not: 'CANCELLED' }
      },
      data: {
        status: 'CANCELLED',
        cancellationReason: 'User deactivated from platform'
      }
    });

    await this.auditLog.log({
      action: 'USER_DEACTIVATED',
      targetUserId: user.id,
      metadata: { source: 'platform_sync' }
    });

    return { success: true, message: 'User deactivated successfully' };
  }

  private async createDefaultSchedule(userId: number) {
    // Create a default Monday-Friday 9-5 schedule
    const schedule = await this.prisma.schedule.create({
      data: {
        name: 'Working Hours',
        userId,
        timeZone: 'America/New_York',
        availability: {
          create: [
            { days: [1, 2, 3, 4, 5], startTime: 540, endTime: 1020 } // 9 AM - 5 PM
          ]
        }
      }
    });

    // Set as default schedule
    await this.prisma.user.update({
      where: { id: userId },
      data: { defaultScheduleId: schedule.id }
    });

    return schedule;
  }

  async getSyncStatus(from?: string, to?: string) {
    const where: any = {};
    
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = new Date(from);
      if (to) where.createdAt.lte = new Date(to);
    }

    const syncStatuses = await this.prisma.platformSyncStatus.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 100
    });

    const stats = await this.prisma.user.aggregate({
      where: { syncedFromPlatform: true },
      _count: true
    });

    return {
      totalSyncedUsers: stats._count,
      recentSyncs: syncStatuses
    };
  }

  async registerWebhooks(config: any) {
    // Implementation for webhook registration
    return this.webhookService.register(config);
  }
}
```

#### Admin Operations Controller

```typescript
// /apps/api/v2/src/modules/admin-operations/controllers/admin-users.controller.ts

import { Controller, Get, Post, Put, Query, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AdminGuard } from '../guards/admin.guard';
import { AdminOperationsService } from '../services/admin-operations.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuditLog } from '../../common/decorators/audit-log.decorator';

@ApiTags('Admin Operations')
@Controller('api/v2/admin')
@UseGuards(AdminGuard)
export class AdminUsersController {
  constructor(private readonly adminService: AdminOperationsService) {}

  @Get('users')
  @ApiOperation({ summary: 'Get all users with filters' })
  async getAllUsers(
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 50,
    @Query('search') search?: string,
    @Query('role') role?: string
  ) {
    return this.adminService.getAllUsers({ page, limit, search, role });
  }

  @Get('users/:userId/calendars')
  @ApiOperation({ summary: 'Get all calendars for a user' })
  async getUserCalendars(@Param('userId') userId: number) {
    return this.adminService.getUserCalendars(userId);
  }

  @Get('users/:userId/availability')
  @ApiOperation({ summary: 'Get user availability' })
  async getUserAvailability(
    @Param('userId') userId: number,
    @Query('from') from: string,
    @Query('to') to: string
  ) {
    return this.adminService.getUserAvailability(userId, from, to);
  }

  @Post('users/:userId/bookings')
  @ApiOperation({ summary: 'Create booking on behalf of user' })
  @AuditLog('ADMIN_CREATE_BOOKING')
  async createBookingForUser(
    @Param('userId') userId: number,
    @Body() bookingData: any,
    @CurrentUser() admin: any
  ) {
    return this.adminService.createBookingForUser(userId, bookingData, admin.id);
  }

  @Get('users/:userId/bookings')
  @ApiOperation({ summary: 'Get all bookings for a user' })
  async getUserBookings(
    @Param('userId') userId: number,
    @Query('status') status?: string,
    @Query('from') from?: string,
    @Query('to') to?: string
  ) {
    return this.adminService.getUserBookings(userId, { status, from, to });
  }

  @Put('users/:userId/event-types/:eventTypeId')
  @ApiOperation({ summary: 'Update user event type' })
  @AuditLog('ADMIN_UPDATE_EVENT_TYPE')
  async updateUserEventType(
    @Param('userId') userId: number,
    @Param('eventTypeId') eventTypeId: number,
    @Body() updateData: any,
    @CurrentUser() admin: any
  ) {
    return this.adminService.updateUserEventType(userId, eventTypeId, updateData, admin.id);
  }

  @Get('dashboard/stats')
  @ApiOperation({ summary: 'Get admin dashboard statistics' })
  async getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  @Get('audit-logs')
  @ApiOperation({ summary: 'Get audit logs' })
  async getAuditLogs(
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 100,
    @Query('adminId') adminId?: number,
    @Query('targetUserId') targetUserId?: number,
    @Query('action') action?: string
  ) {
    return this.adminService.getAuditLogs({ page, limit, adminId, targetUserId, action });
  }
}
```

### 3. Frontend Admin Dashboard

#### Component Structure
```
/apps/web/modules/admin/
├── components/
│   ├── AdminLayout.tsx
│   ├── UserManagementTable.tsx
│   ├── CalendarOverview.tsx
│   ├── BookingCreator.tsx
│   ├── BulkOperations.tsx
│   └── AuditLogViewer.tsx
├── views/
│   ├── AdminDashboard.tsx
│   ├── UserDetailsView.tsx
│   └── PlatformSyncStatus.tsx
├── hooks/
│   ├── useAdminUsers.ts
│   ├── useAdminBookings.ts
│   └── useAuditLogs.ts
└── utils/
    └── adminHelpers.ts
```

#### Admin Dashboard Component

```typescript
// /apps/web/modules/admin/views/AdminDashboard.tsx

import React, { useState } from 'react';
import { useSession } from 'next-auth/react';
import { Card, CardContent, CardHeader, CardTitle } from '@calcom/ui';
import { Users, Calendar, Activity, Settings } from 'lucide-react';
import { UserManagementTable } from '../components/UserManagementTable';
import { CalendarOverview } from '../components/CalendarOverview';
import { PlatformSyncStatus } from './PlatformSyncStatus';
import { AuditLogViewer } from '../components/AuditLogViewer';

export function AdminDashboard() {
  const { data: session } = useSession();
  const [activeTab, setActiveTab] = useState('users');

  if (!session?.user?.role || !['ADMIN', 'PLATFORM_ADMIN'].includes(session.user.role)) {
    return <div>Access Denied: Admin privileges required</div>;
  }

  const tabs = [
    { id: 'users', label: 'User Management', icon: Users },
    { id: 'calendars', label: 'Calendar Overview', icon: Calendar },
    { id: 'sync', label: 'Platform Sync', icon: Activity },
    { id: 'audit', label: 'Audit Logs', icon: Settings },
  ];

  return (
    <div className="admin-dashboard p-6">
      <h1 className="text-2xl font-bold mb-6">Admin Dashboard</h1>
      
      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <StatsCard title="Total Users" value="1,234" change="+12%" />
        <StatsCard title="Active Bookings" value="456" change="+5%" />
        <StatsCard title="Synced Users" value="789" change="+18%" />
        <StatsCard title="Today's Actions" value="45" change="+23%" />
      </div>

      {/* Tab Navigation */}
      <div className="border-b mb-6">
        <nav className="flex space-x-8">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`py-2 px-4 border-b-2 ${
                activeTab === tab.id
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              <tab.icon className="inline-block w-5 h-5 mr-2" />
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      <div className="tab-content">
        {activeTab === 'users' && <UserManagementTable />}
        {activeTab === 'calendars' && <CalendarOverview />}
        {activeTab === 'sync' && <PlatformSyncStatus />}
        {activeTab === 'audit' && <AuditLogViewer />}
      </div>
    </div>
  );
}

function StatsCard({ title, value, change }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-gray-600">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <p className="text-xs text-green-600">{change} from last month</p>
      </CardContent>
    </Card>
  );
}
```

#### User Management Table Component

```typescript
// /apps/web/modules/admin/components/UserManagementTable.tsx

import React, { useState, useEffect } from 'react';
import { useAdminUsers } from '../hooks/useAdminUsers';
import { DataTable } from '@calcom/ui';
import { Button, Input, Select } from '@calcom/ui';
import { Eye, Calendar, Edit, UserCheck } from 'lucide-react';
import { useRouter } from 'next/navigation';

export function UserManagementTable() {
  const router = useRouter();
  const [filters, setFilters] = useState({
    search: '',
    role: 'all',
    syncStatus: 'all',
    page: 1,
    limit: 25
  });

  const { users, loading, totalCount, refetch } = useAdminUsers(filters);

  const columns = [
    {
      header: 'User',
      accessor: 'name',
      cell: ({ row }) => (
        <div className="flex items-center space-x-3">
          <img
            src={row.avatarUrl || '/default-avatar.png'}
            alt={row.name}
            className="w-8 h-8 rounded-full"
          />
          <div>
            <div className="font-medium">{row.name}</div>
            <div className="text-sm text-gray-500">{row.email}</div>
          </div>
        </div>
      )
    },
    {
      header: 'Username',
      accessor: 'username',
    },
    {
      header: 'Role',
      accessor: 'role',
      cell: ({ value }) => (
        <span className={`px-2 py-1 rounded text-xs ${
          value === 'ADMIN' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'
        }`}>
          {value}
        </span>
      )
    },
    {
      header: 'Platform Sync',
      accessor: 'syncedFromPlatform',
      cell: ({ value, row }) => (
        <div>
          {value ? (
            <span className="text-green-600">✓ Synced</span>
          ) : (
            <span className="text-gray-400">Manual</span>
          )}
          {row.externalPlatformId && (
            <div className="text-xs text-gray-500">ID: {row.externalPlatformId}</div>
          )}
        </div>
      )
    },
    {
      header: 'Bookings',
      accessor: 'bookingCount',
      cell: ({ value }) => (
        <div className="text-center">{value || 0}</div>
      )
    },
    {
      header: 'Actions',
      accessor: 'id',
      cell: ({ row }) => (
        <div className="flex space-x-2">
          <Button
            size="sm"
            variant="ghost"
            onClick={() => router.push(`/admin/users/${row.id}`)}
            title="View Details"
          >
            <Eye className="w-4 h-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => router.push(`/admin/users/${row.id}/calendar`)}
            title="View Calendar"
          >
            <Calendar className="w-4 h-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => handleImpersonate(row.id)}
            title="Impersonate User"
          >
            <UserCheck className="w-4 h-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => router.push(`/admin/users/${row.id}/edit`)}
            title="Edit User"
          >
            <Edit className="w-4 h-4" />
          </Button>
        </div>
      )
    }
  ];

  const handleImpersonate = async (userId: number) => {
    // Implement impersonation logic
    if (confirm('Are you sure you want to impersonate this user?')) {
      await fetch('/api/admin/impersonate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId })
      });
      window.location.href = '/';
    }
  };

  return (
    <div className="user-management">
      {/* Filters */}
      <div className="flex space-x-4 mb-6">
        <Input
          placeholder="Search users..."
          value={filters.search}
          onChange={(e) => setFilters({ ...filters, search: e.target.value })}
          className="max-w-xs"
        />
        <Select
          value={filters.role}
          onChange={(e) => setFilters({ ...filters, role: e.target.value })}
        >
          <option value="all">All Roles</option>
          <option value="USER">User</option>
          <option value="ADMIN">Admin</option>
          <option value="PLATFORM_ADMIN">Platform Admin</option>
        </Select>
        <Select
          value={filters.syncStatus}
          onChange={(e) => setFilters({ ...filters, syncStatus: e.target.value })}
        >
          <option value="all">All Users</option>
          <option value="synced">Synced Only</option>
          <option value="manual">Manual Only</option>
        </Select>
        <Button onClick={refetch}>Refresh</Button>
      </div>

      {/* Data Table */}
      <DataTable
        columns={columns}
        data={users}
        loading={loading}
        pagination={{
          page: filters.page,
          pageSize: filters.limit,
          totalCount,
          onPageChange: (page) => setFilters({ ...filters, page })
        }}
      />
    </div>
  );
}
```

### 4. Security Implementation

#### API Authentication Guard

```typescript
// /apps/api/v2/src/modules/platform-sync/guards/platform-api-key.guard.ts

import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '@calcom/prisma';
import * as crypto from 'crypto';

@Injectable()
export class PlatformApiKeyGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const apiKey = request.headers['x-platform-api-key'];

    if (!apiKey) {
      throw new UnauthorizedException('Platform API key is required');
    }

    // Hash the API key for comparison
    const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');

    const platformKey = await this.prisma.platformApiKey.findUnique({
      where: { key: hashedKey }
    });

    if (!platformKey || !platformKey.isActive) {
      throw new UnauthorizedException('Invalid or inactive API key');
    }

    // Check expiration
    if (platformKey.expiresAt && platformKey.expiresAt < new Date()) {
      throw new UnauthorizedException('API key has expired');
    }

    // Update last used timestamp
    await this.prisma.platformApiKey.update({
      where: { id: platformKey.id },
      data: { lastUsedAt: new Date() }
    });

    // Attach platform info to request
    request.platform = {
      id: platformKey.id,
      name: platformKey.platformName,
      permissions: platformKey.permissions
    };

    return true;
  }
}
```

#### Audit Log Service

```typescript
// /apps/api/v2/src/modules/admin-operations/services/audit-log.service.ts

import { Injectable } from '@nestjs/common';
import { PrismaService } from '@calcom/prisma';

interface AuditLogEntry {
  action: string;
  adminId?: number;
  targetUserId?: number;
  resourceType?: string;
  resourceId?: number;
  metadata?: any;
  ipAddress?: string;
  userAgent?: string;
}

@Injectable()
export class AuditLogService {
  constructor(private prisma: PrismaService) {}

  async log(entry: AuditLogEntry) {
    return this.prisma.adminAuditLog.create({
      data: entry
    });
  }

  async getAuditLogs(filters: any) {
    const { page = 1, limit = 100, adminId, targetUserId, action } = filters;
    
    const where: any = {};
    if (adminId) where.adminId = adminId;
    if (targetUserId) where.targetUserId = targetUserId;
    if (action) where.action = action;

    const [logs, total] = await Promise.all([
      this.prisma.adminAuditLog.findMany({
        where,
        include: {
          admin: {
            select: { id: true, name: true, email: true }
          },
          targetUser: {
            select: { id: true, name: true, email: true }
          }
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit
      }),
      this.prisma.adminAuditLog.count({ where })
    ]);

    return {
      logs,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    };
  }

  async exportAuditLogs(filters: any, format: 'json' | 'csv' = 'json') {
    const logs = await this.prisma.adminAuditLog.findMany({
      where: filters,
      include: {
        admin: true,
        targetUser: true
      },
      orderBy: { createdAt: 'desc' }
    });

    if (format === 'csv') {
      return this.convertToCSV(logs);
    }

    return logs;
  }

  private convertToCSV(logs: any[]): string {
    const headers = ['Timestamp', 'Admin', 'Action', 'Target User', 'Resource', 'IP Address'];
    const rows = logs.map(log => [
      log.createdAt.toISOString(),
      log.admin?.email || 'System',
      log.action,
      log.targetUser?.email || 'N/A',
      `${log.resourceType || ''}:${log.resourceId || ''}`,
      log.ipAddress || 'N/A'
    ]);

    return [headers, ...rows].map(row => row.join(',')).join('\n');
  }
}
```

## API Specifications

### Authentication

All platform API endpoints require authentication using an API key passed in the header:

```
X-Platform-API-Key: your-platform-api-key
```

### Endpoints

#### User Sync Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v2/platform-sync/users` | Create or update a single user |
| POST | `/api/v2/platform-sync/users/bulk` | Bulk sync multiple users |
| GET | `/api/v2/platform-sync/users/:platformId` | Get user by platform ID |
| PUT | `/api/v2/platform-sync/users/:platformId` | Update user by platform ID |
| DELETE | `/api/v2/platform-sync/users/:platformId` | Deactivate user |
| GET | `/api/v2/platform-sync/sync-status` | Get sync status and statistics |

#### Admin Operations Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v2/admin/users` | Get all users with filters |
| GET | `/api/v2/admin/users/:userId/calendars` | Get user's calendars |
| GET | `/api/v2/admin/users/:userId/availability` | Get user availability |
| POST | `/api/v2/admin/users/:userId/bookings` | Create booking for user |
| GET | `/api/v2/admin/users/:userId/bookings` | Get user's bookings |
| PUT | `/api/v2/admin/users/:userId/event-types/:id` | Update event type |
| GET | `/api/v2/admin/dashboard/stats` | Get dashboard statistics |
| GET | `/api/v2/admin/audit-logs` | Get audit logs |

### Request/Response Examples

#### Create/Update User

**Request:**
```json
POST /api/v2/platform-sync/users
X-Platform-API-Key: your-api-key
Content-Type: application/json

{
  "externalId": "platform_user_123",
  "email": "john.doe@example.com",
  "name": "John Doe",
  "username": "johndoe",
  "metadata": {
    "department": "Engineering",
    "employeeId": "EMP001",
    "customFields": {
      "office": "San Francisco",
      "team": "Platform"
    }
  }
}
```

**Response:**
```json
{
  "success": true,
  "userId": 456,
  "externalId": "platform_user_123",
  "message": "User created successfully",
  "user": {
    "id": 456,
    "email": "john.doe@example.com",
    "name": "John Doe",
    "username": "johndoe",
    "syncedFromPlatform": true,
    "lastSyncedAt": "2024-01-15T10:30:00Z"
  }
}
```

#### Bulk Sync Users

**Request:**
```json
POST /api/v2/platform-sync/users/bulk
X-Platform-API-Key: your-api-key
Content-Type: application/json

{
  "users": [
    {
      "externalId": "user_001",
      "email": "user1@example.com",
      "name": "User One"
    },
    {
      "externalId": "user_002",
      "email": "user2@example.com",
      "name": "User Two"
    }
  ]
}
```

**Response:**
```json
{
  "successful": [
    {
      "success": true,
      "userId": 457,
      "externalId": "user_001"
    }
  ],
  "failed": [
    {
      "externalId": "user_002",
      "error": "Email already exists"
    }
  ],
  "total": 2,
  "successCount": 1,
  "failedCount": 1
}
```

## Security & Compliance

### Security Measures

1. **API Key Management**
   - Keys are hashed using SHA-256 before storage
   - Support for key rotation and expiration
   - Rate limiting per API key
   - IP allowlisting optional

2. **Audit Logging**
   - All admin actions are logged
   - Immutable audit trail
   - Searchable and exportable logs
   - Retention policies configurable

3. **Data Protection**
   - Encryption at rest for sensitive data
   - TLS 1.3 for data in transit
   - PII data masking in logs
   - GDPR-compliant data handling

4. **Access Control**
   - Role-based permissions (RBAC)
   - Principle of least privilege
   - Session timeout for admin actions
   - Multi-factor authentication support

### Compliance Considerations

1. **GDPR Compliance**
   - Right to erasure implementation
   - Data portability via export APIs
   - Consent management for synced users
   - Privacy by design principles

2. **SOC 2 Requirements**
   - Change management procedures
   - Access review processes
   - Security incident response
   - Business continuity planning

3. **HIPAA Considerations** (if applicable)
   - PHI data handling procedures
   - Access controls and audit logs
   - Encryption requirements
   - Business Associate Agreements

## Implementation Timeline

### Phase 1: Foundation (Week 1)
- **Day 1-2**: Database schema updates and migrations
- **Day 3-4**: Basic API structure and authentication
- **Day 5**: Initial user sync endpoints
- **Weekend**: Testing and documentation

### Phase 2: Core Features (Week 2)
- **Day 1-2**: Platform sync service implementation
- **Day 3-4**: Admin operations APIs
- **Day 5**: Webhook system
- **Weekend**: Integration testing

### Phase 3: Admin UI (Week 3)
- **Day 1-2**: Admin dashboard layout and navigation
- **Day 3-4**: User management interface
- **Day 5**: Calendar and booking management
- **Weekend**: UI testing and refinement

### Phase 4: Advanced Features (Week 4)
- **Day 1-2**: Bulk operations and performance optimization
- **Day 3-4**: Audit log viewer and export
- **Day 5**: Platform sync status dashboard
- **Weekend**: Load testing

### Phase 5: Security & Testing (Week 5)
- **Day 1-2**: Security hardening and penetration testing
- **Day 3-4**: Performance optimization
- **Day 5**: Documentation completion
- **Weekend**: Final testing and bug fixes

### Phase 6: Deployment (Week 6)
- **Day 1**: Staging deployment
- **Day 2-3**: User acceptance testing
- **Day 4**: Production deployment preparation
- **Day 5**: Production rollout
- **Weekend**: Monitoring and support

## Testing Strategy

### Unit Testing

```typescript
// Example test for PlatformSyncService
describe('PlatformSyncService', () => {
  let service: PlatformSyncService;
  let prisma: PrismaService;

  beforeEach(() => {
    // Setup test environment
  });

  describe('syncUser', () => {
    it('should create new user when not exists', async () => {
      const userData = {
        externalId: 'test_123',
        email: 'test@example.com',
        name: 'Test User'
      };

      const result = await service.syncUser(userData);
      
      expect(result.success).toBe(true);
      expect(result.message).toContain('created');
    });

    it('should update existing user', async () => {
      // Test update logic
    });
  });
});
```

### Integration Testing

```typescript
// Example integration test
describe('Admin Operations E2E', () => {
  it('should allow admin to create booking for user', async () => {
    const response = await request(app)
      .post('/api/v2/admin/users/123/bookings')
      .set('Authorization', 'Bearer admin-token')
      .send({
        eventTypeId: 1,
        start: '2024-01-20T10:00:00Z',
        end: '2024-01-20T11:00:00Z',
        attendees: [{ email: 'guest@example.com' }]
      });

    expect(response.status).toBe(201);
    expect(response.body.booking).toBeDefined();
  });
});
```

### Load Testing

```javascript
// k6 load test script
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '5m', target: 100 },
    { duration: '10m', target: 100 },
    { duration: '5m', target: 0 },
  ],
};

export default function() {
  const payload = JSON.stringify({
    externalId: `user_${Math.random()}`,
    email: `test${Math.random()}@example.com`,
    name: 'Load Test User'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Platform-API-Key': 'test-api-key'
    },
  };

  const response = http.post('http://localhost:3000/api/v2/platform-sync/users', payload, params);
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}
```

## Deployment Guide

### Environment Variables

```bash
# Add to .env file

# Platform Sync Configuration
PLATFORM_API_KEY=your-secure-api-key
PLATFORM_WEBHOOK_SECRET=webhook-secret-key
ENABLE_PLATFORM_SYNC=true
PLATFORM_SYNC_BATCH_SIZE=100
PLATFORM_SYNC_RATE_LIMIT=1000

# Admin Features
ENABLE_ADMIN_MODE=true
ADMIN_DASHBOARD_URL=/admin
PLATFORM_ADMIN_EMAILS=admin@platform.com,admin2@platform.com
ADMIN_SESSION_TIMEOUT=3600

# Security
AUDIT_LOG_RETENTION_DAYS=90
ENABLE_ADMIN_MFA=true
IP_WHITELIST_ENABLED=false
IP_WHITELIST=192.168.1.0/24,10.0.0.0/8

# Integration
WEBHOOK_RETRY_ATTEMPTS=3
WEBHOOK_TIMEOUT_MS=5000
```

### Database Migrations

```bash
# Create migration files
yarn prisma migrate dev --name add_platform_sync_fields

# Apply migrations to production
yarn prisma migrate deploy

# Seed initial admin users
yarn prisma db seed
```

### Docker Deployment

```dockerfile
# Dockerfile additions for admin features
FROM node:18-alpine AS builder

# Install additional dependencies
RUN apk add --no-cache python3 make g++

# Copy and build admin modules
COPY apps/web/modules/admin ./apps/web/modules/admin
COPY apps/api/v2/src/modules/platform-sync ./apps/api/v2/src/modules/platform-sync
COPY apps/api/v2/src/modules/admin-operations ./apps/api/v2/src/modules/admin-operations

# Build with admin features enabled
ENV ENABLE_ADMIN_MODE=true
RUN yarn build
```

### Kubernetes Configuration

```yaml
# admin-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: calcom-admin
spec:
  replicas: 2
  selector:
    matchLabels:
      app: calcom-admin
  template:
    metadata:
      labels:
        app: calcom-admin
    spec:
      containers:
      - name: calcom
        image: calcom/cal.com:admin-latest
        env:
        - name: ENABLE_ADMIN_MODE
          value: "true"
        - name: PLATFORM_API_KEY
          valueFrom:
            secretKeyRef:
              name: calcom-secrets
              key: platform-api-key
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

### Monitoring Setup

```yaml
# Prometheus metrics for admin operations
- job_name: 'calcom-admin'
  static_configs:
    - targets: ['calcom-admin:3000']
  metrics_path: '/api/metrics'
  params:
    module: ['admin']
```

### Backup Strategy

```bash
#!/bin/bash
# backup-admin-data.sh

# Backup audit logs
pg_dump $DATABASE_URL \
  --table=AdminAuditLog \
  --table=PlatformSyncStatus \
  --table=PlatformApiKey \
  > admin_backup_$(date +%Y%m%d).sql

# Archive to S3
aws s3 cp admin_backup_$(date +%Y%m%d).sql \
  s3://backups/calcom/admin/
```

## Troubleshooting Guide

### Common Issues

1. **Sync Failures**
   - Check API key validity
   - Verify network connectivity
   - Review rate limits
   - Check user data validation

2. **Performance Issues**
   - Enable database query logging
   - Check index usage
   - Review bulk operation batch sizes
   - Monitor memory usage

3. **Authentication Problems**
   - Verify admin role assignment
   - Check session expiration
   - Review IP restrictions
   - Validate API key permissions

### Debug Commands

```bash
# Check sync status
curl -H "X-Platform-API-Key: $API_KEY" \
  http://localhost:3000/api/v2/platform-sync/sync-status

# View recent audit logs
psql $DATABASE_URL -c \
  "SELECT * FROM AdminAuditLog ORDER BY createdAt DESC LIMIT 10;"

# Test user sync
curl -X POST \
  -H "X-Platform-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"externalId":"test_user","email":"test@example.com"}' \
  http://localhost:3000/api/v2/platform-sync/users
```

## Appendix

### Glossary

- **Platform Sync**: Process of synchronizing user data from external platform to Cal.com
- **Admin Mode**: Enhanced privileges allowing management of all users
- **External Platform ID**: Unique identifier from the source platform
- **Audit Log**: Immutable record of administrative actions
- **Bulk Operations**: Actions performed on multiple records simultaneously

### References

- [Cal.com Documentation](https://cal.com/docs)
- [Prisma Documentation](https://www.prisma.io/docs)
- [Next.js Documentation](https://nextjs.org/docs)
- [NestJS Documentation](https://docs.nestjs.com)

### Contact Information

For questions or support regarding this implementation:
- Technical Lead: [Your Name]
- Project Manager: [PM Name]
- Security Team: security@yourcompany.com

---

*Document Version: 1.0*  
*Last Updated: January 2024*  
*Next Review: February 2024*