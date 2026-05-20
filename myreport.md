# Change Report

## Overview
This document captures the evolution of the current workspace—from initial setup through feature expansion. The journey addressed backend startup and schema concerns, resolved scheduler errors, established a structured OTP/register/login flow, and implemented robust auth persistence. Each phase built upon the previous, creating a more cohesive system.

---

## Files Changed

### 1. `backend/config/database.js` (approx. lines 33-152)
Backend startup was experiencing failures due to missing DB schema elements and incorrect auto-migration behavior. The system needed a more robust approach to schema initialization.

- **What was addressed**:
  - Added `runQuerySafe()` for safe `CREATE TABLE` / `ALTER TABLE` execution.
  - Added `ensureColumn()` to detect and add missing columns via `information_schema.columns`.
  - Added `ensureTablesAndColumns()` to create missing tables and add required columns:
    - `lead_reminders` with `missed_count INT DEFAULT 0`
    - `lead_escalations` with `missed_count INT DEFAULT 0`
    - `admin_notifications`
    - `users.status` enum column
    - several `assigned_to`, `created_by`, `lead_id`, `lead_type` columns used by existing routes and scheduler.
  - Ensured the schema initialization path calls `ensureTablesAndColumns()` after loading `schema.sql`.
- **Rolling back**: Removing the `ensureColumn()` and `ensureTablesAndColumns()` functions would return to the previous approach. Restoring the original database connect/initialization block would undo these schema adjustments. The new `admin_notifications` and `users.status` auto-add logic could be removed if keeping the original schema only was preferred.

> *Created by ANNATH-dev* - Should additional schema tables be documented in future iterations?

### 2. `backend/routes/authRoutes.js` (approx. lines 81-130)
The registration and login flow needed attention—missing user status fields, lack of admin notification support, and insufficient session persistence were creating friction in the authentication flow.

- **What was addressed**:
  - Normalized email values using `trim().toLowerCase()` before database operations.
  - New registrations now receive `status='pending'` with admin notification entries created for each signup.
  - Account approval checks were added during login to handle `pending` and `rejected` status states.
  - JWT token expiry extended from default to `14d`, allowing login to persist across browser sessions for two weeks.
- **Rolling back**: Removing the `status` handling from registration and login would reverse the approval flow. The `INSERT INTO admin_notifications` query could be removed. Resetting the JWT expiry clause to prior configuration (for example, `expiresIn: "1d"`) would shorten session persistence.

> *Created by ANNATH-dev* - Is the 14d token expiry working as expected for your use case?

### 3. `backend/backendutil/sendSms.js` (approx. lines 1-30)
Email delivery needed to be more resilient—the OTP sending process could fail silently when the mail transporter wasn't properly initialized or authenticated.

- **What was addressed**:
  - Added `transporter.verify()` logging to detect SMTP authentication or connection issues at startup.
  - Kept `sendEmailOtp()` unchanged while making email sending behavior more observable for debugging.
- **Rolling back**: Removing the `transporter.verify()` block would revert to the original simpler approach. Keeping the original `nodemailer.createTransport()` and `sendMail()` flow would maintain less visibility into SMTP issues.

> *Created by ANNATH-dev* - Would you like to add SMS delivery tracking in future updates?

### 4. `backend/backendutil/reminderScheduler.js` (approx. lines 11-60)
The scheduler was experiencing failures—missing `missed_count` tracking and invalid `reminder_time` comparisons were causing reminders to slip through without proper escalation handling.

- **What was addressed**:
  - Added `missed_count` handling to ensure overdue reminders are tracked properly.
  - Implemented `TIME(reminder_time) < ?` comparison to correctly match stored `TIME` values against the current time.
  - Built robust escalation logic that triggers after marking reminders as missed.
- **Rolling back**: Removing the `missed_count` update logic from the `UPDATE lead_reminders` query would undo the tracking enhancement. Restoring the original reminder-time comparison logic (if the previous code didn't use `TIME(reminder_time)`) would revert to the earlier approach.

> *Created by ANNATH-dev* - Is the escalation timing configured correctly for your team's workflow?

### 5. `backend/routes/leadManagementRoutes.js` (approx. lines 70-100)
Reminder marking and escalation checks needed proper `TIME(reminder_time)` handling in SQL queries.

- **What was addressed**:
  - Normalized the `check-missed` query to compare `TIME(reminder_time)` against the current time string.
  - Prevented invalid datetime comparisons when only a `TIME` value is stored.
- **Rolling back**: Restoring the previous `UPDATE lead_reminders` query without `TIME(reminder_time)` would return to the simpler approach.

> *Created by ANNATH-dev* - Are there any additional reminder rules or conditions that should be added?

### 6. `backend/schema.sql` (approx. lines 319-333)
The database schema was missing key elements for user status tracking and admin notification workflows.

- **What was addressed**:
  - Added `status ENUM('pending','active','rejected') DEFAULT 'pending'` to the `users` table.
  - Created the `admin_notifications` table to support registration approval workflows.
- **Rolling back**: Removing the `status` column from `CREATE TABLE IF NOT EXISTS users` would undo the user status tracking. Deleting the `CREATE TABLE IF NOT EXISTS admin_notifications` block would remove notification support.

> *Created by ANNATH-dev* - Should the status enum values be expandable (e.g., 'suspended', 'archived')?

### 7. `frontend/src/auth/AuthContext.jsx` (approx. lines 6-25)
Authentication state was being lost on page refresh because it was stored in `sessionStorage`, which cleared when the browser closed.

- **What was addressed**:
  - Switched to `localStorage` so users remain logged in across browser sessions for the full token lifetime.
  - Both `user` and `token` entries are now persisted in local storage upon login.
- **Rolling back**: Replacing `localStorage` calls with `sessionStorage` calls would return to session-only persistence. The previous `useState` loader could be restored to read from session storage instead.

> *Created by ANNATH-dev* - Would you like to add a token refresh mechanism for extended sessions?

### 8. `frontend/src/auth/login.jsx` (approx. lines 1-60)
The login flow needed adjustment—email normalization was inconsistent and the returned token wasn't being stored properly in auth state.

- **What was addressed**:
  - Normalized the login email with `trim().toLowerCase()` for consistent matching.
  - The login function now calls `login({ ...res.data.user, token: res.data.token })` on successful authentication.
  - Added clearer error handling for 404 and 403 responses.
- **Rolling back**: Restoring any previous login payload handling would revert to prior auth shape. Removing the `token` from the `login()` call would undo token persistence in the flow.

> *Created by ANNATH-dev* - Would you like to add a "remember me" checkbox option?

---

## New Features Added (Phase 2 - Dashboard & Reports)

### 9. Profile Page (`frontend/src/pages/profile.jsx`)
A user profile management page became necessary for viewing and editing personal details directly in the application.

- **How it came together**:
  - View mode displays user details: name, email, phone, address, company
  - Edit mode provides form fields to update profile information
  - Change Password modal includes current password, new password, and confirm password fields
  - Backend integration through: `GET /api/auth/profile`, `PUT /api/auth/profile`, `POST /api/auth/change-password`
- **Files created**: `frontend/src/pages/profile.jsx`
- **Rolling back**: Removing the profile route from App.js and deleting `profile.jsx` would undo this feature.

> *Created by ANNATH-dev* - Is profile photo upload functionality needed?

### 10. Settings Page (`frontend/src/pages/settings.jsx`)
A comprehensive settings page emerged to give users control over their preferences and security options.

- **How it came together**:
  - **Theme Settings**: Light/Dark mode toggle with color scheme options
  - **Notification Settings**: Email notifications, SMS alerts, push notifications toggles
  - **Security Settings**: Two-factor authentication, session management, login history
  - **Preferences**: Language selection, timezone, date format, currency format
  - Save/Cancel buttons with local state management
- **Files created**: `frontend/src/pages/settings.jsx`
- **Rolling back**: Removing the settings route from App.js and deleting `settings.jsx` would undo this feature.

> *Created by ANNATH-dev* - Are there additional setting categories that should be included?

### 11. Backend Profile & Password Endpoints (`backend/routes/authRoutes.js`)
The profile and settings pages required corresponding backend API support to function properly.

- **How it came together**:
  - `GET /api/auth/profile` - Returns current user's profile data
  - `PUT /api/auth/profile` - Updates user profile (name, phone, address, etc.)
  - `POST /api/auth/change-password` - Validates current password and updates to new one
- **Code location**: New route handlers added in `backend/routes/authRoutes.js`
- **Rolling back**: Removing the route handlers for profile and change-password would revert these additions.

> *Created by ANNATH-dev* - Should a profile picture upload endpoint be added?

### 12. Task Accept/Decline Workflow (`backend/routes/taskRoutes.js`, `frontend/src/pages/task.jsx`)
A workflow for employees to respond to assigned tasks became essential—with INR-based targets replacing simple task counts.

- **How it came together**:
  - Backend endpoint `POST /api/task/:id/respond` accepts `action` (accept/decline) with optional `decline_reason`
  - Admin notifications trigger when an employee declines a task
  - INR-based target system: shifted from task count to monetary amounts
  - Employee dropdown in task assignment form pulls from `/api/teammember` endpoint
  - Target achievement progress displays in INR
- **Files modified**: `backend/routes/taskRoutes.js`, `frontend/src/pages/task.jsx`
- **Rolling back**: Removing the accept/decline buttons and INR target logic from task.jsx would undo this workflow.

> *Created by ANNATH-dev* - Would you like to add task comments/notes functionality?

### 13. Client Dropdown in AMC Contract Form (`frontend/src/pages/amc.jsx`)
The AMC contract form needed to select from existing clients rather than requiring manual entry of client details.

- **How it came together**:
  - Client dropdown fetches data from `/dashboard/clients` API
  - Client details auto-fill when selecting from the dropdown
  - Contract value stores as exact INR (not broken into components)
- **Files modified**: `frontend/src/pages/amc.jsx`
- **Rolling back**: Removing the client dropdown and related fetch logic would revert to manual entry.

> *Created by ANNATH-dev* - Would a searchable client dropdown be helpful?

### 14. Convert to Client Buttons (`frontend/src/pages/telecalling.jsx`, `walkins.jsx`, `field.jsx`)
Making it easier to convert leads to clients across Telecalling, Walkins, and Field Work pages improved the user workflow significantly.

- **How it came together**:
  - "Convert to Client" button added to each lead row
  - Client record creates from lead data: customer_name, phone, email, address
  - Lead ID and lead type stored in client record for tracking
  - Cross-page data flow handled through sessionStorage (`contract_prefill`, `quotation_prefill`)
- **Files modified**: `frontend/src/pages/telecalling.jsx`, `frontend/src/pages/walkins.jsx`, `frontend/src/pages/field.jsx`
- **Rolling back**: Removing the Convert to Client buttons and client creation logic would return to the earlier approach.

> *Created by ANNATH-dev* - Should a bulk lead conversion option be added?

### 15. Contract Filter in AMC Services Tab (`frontend/src/pages/amc.jsx`)
Filtering AMC services by contract became important for better organization and quick access to related services.

- **How it came together**:
  - Contract dropdown filter added in AMC services tab
  - "View Services" button reveals all services for selected contract
  - Service details appear in modal/drawer
  - Quotation link included in service rows to view associated quotation
- **Files modified**: `frontend/src/pages/amc.jsx`
- **Rolling back**: Removing the contract filter and View Services functionality would revert to the unfiltered view.

> *Created by ANNATH-dev* - Should a date range filter be added to the services view?

### 16. Reports Page with Comprehensive Analytics (`frontend/src/pages/reports.jsx`)
A full-featured Reports page developed to provide deep insights across Overview, By Employee, and Trends tabs.

- **How it came together**:

#### Overview Tab
- 5 summary metric cards: Total Sales, Total Leads, Services Done, Revenue, Conversion %
- Monthly Sales & Leads Trend (Line Chart with dual Y-axis)
- Revenue & Services Trend (Area Chart)
- Lead Sources Distribution (Pie Chart)
- Lead Conversion (Pie Chart)
- Employee Performance (Bar Chart)
- Detailed breakdown cards: Telecalls, Walkins, Field Visits, Total Clients
- Monthly Breakdown Table with all metrics

#### By Employee Tab
- Team Performance Summary with 5 metrics (Employees, Total Leads, Converted, Revenue, Avg Conv %)
- Employee selector dropdown for viewing individual employee details
- Individual employee metrics cards with detailed breakdown
- Performance Breakdown Bar Chart (Telecalls, Walkins, Field, Clients, Proposals, Contracts, Services)
- Target Achievement circular progress indicator
- All Employees Comparison Table with sorting:
  - Sort by Leads, Revenue, Conversion, Target, Tasks
  - Columns: #, Employee, Position, Tel, Walk, Field, Leads, Conv%, Clients, Services, Revenue, Target%

#### Trends Tab
- Day/Week/Month/Year filter buttons
- 5 metric cards with gradient colors
- Daily Leads & Services Trend (Line Chart)
- Daily Sales Trend (Area Chart)
- Monthly Comparison (Bar Chart with dual Y-axis)
- Revenue by Month (Composed Chart with Area + Line)
- Detailed Trends Breakdown Table

- **Data pull from**:
  - `/api/teammember` - Employee list
  - `/api/Telecalls` - Telecalling data
  - `/api/Walkins` - Walkins data
  - `/api/Fields` - Field work data
  - `/api/client` - Client data
  - `/api/contract/with-usage` - Contract data
  - `/api/amc/amc-alc` - AMC services
  - `/api/quotations` - Quotations
  - `/api/performainvoice` - Performa invoices
  - `/api/task/targets` - Task targets
  - `/api/task` - Tasks

- **Supporting functions**:
  - `normalizeName()` - Normalizes employee names for matching
  - `isEmployeeMatch()` - Matches employee names across different fields
  - `getEmployeeMetrics()` - Calculates individual employee metrics
  - `getEmployeeComparisonData` - useMemo for comparison data with sorting
  - `getMonthlyTrendData` - useMemo for monthly trend data
  - `getDailyTrendData` - useMemo for daily trend data

- **Files created/modified**: `frontend/src/pages/reports.jsx`
- **Rolling back**: Removing the Reports component and its route would undo this feature.

> *Created by ANNATH-dev* - Would you like to add PDF/Excel export functionality?

### 17. Fix useMemo Function Call Errors
Several useMemo hooks were being called as functions, causing runtime errors in the application.

- **What was addressed**:
  - Changed `getMonthlyTrendData()` to `getMonthlyTrendData` (useMemo returns array directly)
  - Changed `getDailyTrendData()` to `getDailyTrendData`
  - Changed `getEmployeeComparisonData()` to `getEmployeeComparisonData`
  - Used local variables in component functions to capture useMemo values properly
- **Files modified**: `frontend/src/pages/reports.jsx`
- **Rolling back**: Reverting the function call changes would return the errors.

> *Created by ANNATH-dev* - Should performance monitoring be added to track rendering issues?

---

## Architecture & Data Flow

### Dashboard Module Interlinking
```
Leads (Telecalling/Walkins/Field)
    ↓ Convert to Client
Clients
    ↓ Create Contract
Contracts (AMC/Service)
    ↓ Create Services
Services
    ↓ Create Proposal/Quotation
Quotations → Performa Invoices
```

### Cross-Page Data Flow
- **sessionStorage**: Used for prefilling data between pages
  - `contract_prefill` - Prefill contract form from lead conversion
  - `quotation_prefill` - Prefill quotation form from service

### Employee Matching System
- Uses `normalizeName()` to handle various name formats
- Matches by: exact match, partial match (includes), reverse includes
- Checks fields: `staff_name`, `assigned_to`, `service_person`, `created_by`

### API Endpoints Summary
| Endpoint | Purpose |
|----------|---------|
| GET /api/auth/profile | Get user profile |
| PUT /api/auth/profile | Update profile |
| POST /api/auth/change-password | Change password |
| POST /api/task/:id/respond | Accept/Decline task |
| GET /api/task/targets | Get INR-based targets |
| GET /api/teammember | Get team members for dropdowns |

---

## Additional Considerations
A few guiding principles shaped these developments throughout the journey:

- Runtime issues encountered during development were addressed in both backend and frontend, creating a more stable foundation.
- Since this workspace doesn't function as a Git repository, tracking changes happened through careful review of the codebase itself rather than native diffs—a manual but thorough approach to documenting progress.
- Socket.io integration found its way into real-time features where live updates made sense for the user experience.
- Form validation ensures required fields are captured before submission, maintaining data integrity.
- Contract values store as exact INR amounts rather than broken into separate components, simplifying financial tracking.

For anyone looking to understand the flow of how this system came together, tracing through the data relationships—leads flowing into clients, clients into contracts, contracts into services—reveals the natural progression. The employee matching system ties it all together, connecting work across Telecalling, Walkins, Field Work, and reporting.

---

## Role-Based Access Control Implementation (Phase 3 - RBAC)

### Overview
Implemented strict role-based access control (admin / subadmin / employee) across the application. Employee role gets read/create only, subadmin gets full access except user management, and admin gets full access. Subadmin role can be assigned by admin from the team page.

---

### 18. Subadmin Role Support in Auth Middleware (`backend/middleware/authMiddleware.js`)

The authentication middleware needed to recognize a new `subadmin` role that sits between employee and admin in permission hierarchy.

- **What was addressed**:
  - `isAdmin` middleware updated to allow both `admin` and `subadmin` roles: `req.user.role !== "admin" && req.user.role !== "subadmin"`
  - Added new `isReadOnly` middleware to block PUT/DELETE for employee role
  - Role checking pattern: `const role = req.user?.role || "employee"`
- **Rolling back**: Restoring the `isAdmin` check to only allow `"admin"` would revert to admin-only access.

> *Done by ananth-dev* - Should a `manager` role be added in future?

---

### 19. All PUT/DELETE Routes Protected with `isAdmin` (`backend/routes/`)

34 PUT/DELETE routes across 16 backend files were updated to include `isAdmin` permission middleware.

- **Files modified** (all PUT/DELETE routes now have `isAdmin`):
  - `serviceRoutes.js` — service CRUD (image upload fixed)
  - `newclient.js` — client CRUD (full client fields)
  - `amcRoutes.js` — service type + payment fields, contract CRUD
  - `taskRoutes.js` — task CRUD (priority validation fixed, safe default "Medium")
  - `fieldRoutes.js` — field work CRUD
  - `telecallRoutes.js` — telecalling CRUD
  - `walkinRoutes.js` — walkins CRUD
  - `estimate.js` — estimate CRUD
  - `callReportRoutes.js` — call report CRUD (service types fixed: Warranty/Installation/Service Call)
  - `leadManagementRoutes.js` — lead management CRUD
  - `notificationRoutes.js` — notifications CRUD
  - `contract.js` — contract CRUD
  - `invoice.js` — invoice CRUD
  - `quotationRoutes.js` — quotation CRUD
  - `performaInvoiceRoutes.js` — performa invoice CRUD
  - `unifiedInvoiceRoute.js` — unified invoice CRUD

- **Rolling back**: Removing `isAdmin` from any route's middleware array would revert that route to being accessible by any authenticated user.

> *Done by ananth-dev* - Is the permission hierarchy aligned with the team's org structure?

---

### 20. Role Assignment Endpoint (`backend/routes/authRoutes.js`)

Admin needed a way to assign or change a user's system role (employee → subadmin → admin) after account creation.

- **What was added**:
  - `PUT /api/auth/change-role/:id` — allows admin to change any user's role
  - `POST /api/auth/create-user` — now accepts and saves `system_role` field (defaults to "employee")
  - `PUT /api/auth/update-user/:id` — now saves `role` field
- **Rolling back**: Removing the change-role route handler and reverting create-user/update-user to ignore role fields would undo these additions.

> *Done by ananth-dev* - Should subadmin be able to assign roles to employees?

---

### 21. Team Member Page — Role-Based UI (`frontend/src/pages/teammember.jsx`)

The team page needed a modern role-aware interface showing user roles with badges and a role change modal for admins.

- **What was added**:
  - Access column with color-coded badges: admin (blue), subadmin (orange), employee (gray)
  - Zap icon button to open role change modal (admin only)
  - Role Change modal with role selector (Employee/Sub-Admin/Admin) and permission explanation
  - Admin sees: Add, Edit, Delete, Assign Task, Change Role buttons
  - Subadmin sees: Assign Task button only
  - Employee sees: View + Email buttons only
  - `fetchTeam()` uses `/api/teammember/admin` for admin/subadmin, `/api/teammember` for employee
- **Backend updated**: `GET /api/teammember` and `GET /api/teammember/admin` now join `users` table to return `user_role`
- **Files modified**: `backend/routes/team.js`, `frontend/src/pages/teammember.jsx`
- **Rolling back**: Removing the role column, role change modal, and conditional button rendering from team member page would revert to the original view.

> *Done by ananth-dev* - Should a role history log be added to track role changes?

---

### 22. User Management Page — System Role Dropdown (`frontend/src/pages/usermanagement.jsx`)

The user management page needed a System Role field when creating users to set initial role.

- **What was added**:
  - System Role dropdown (Employee/Sub-Admin/Admin) in the create user form
  - Default role: "employee"
  - Form state includes `system_role` field
  - Badge display for subadmin in user list (orange)
  - Role selector in edit mode
- **Rolling back**: Removing the System Role dropdown and reverting formData to exclude `system_role` would undo this addition.

> *Done by ananth-dev* - Should user role be editable from the user management list itself?

---

### 23. Database Auto-Migration (`backend/config/database.js`)

New columns needed to be available in the database without manual migration steps.

- **What was added**:
  - `ensureColumn()` added to `database.js` — detects and adds missing columns via `information_schema`
  - Auto-migration runs on server startup ensuring all new fields exist:
    - `task_description` in tasks table
    - `user_role` / `system_role` in users table
    - `service_type`, `cost_breakdown`, `payment_status` in amc_services table
    - `assigned_to`, `created_by`, `lead_id`, `lead_type` across relevant tables
- **Rolling back**: Disabling the `ensureTablesAndColumns()` call in database initialization would prevent auto-migration on startup.

> *Done by ananth-dev* - Should migration status be logged to a separate table?

---

### 24. Role-Based Button Visibility Across Frontend Pages

Edit and Delete buttons were conditionally hidden for employee role across all listing pages to enforce the permission matrix.

- **Pages updated with `canEditDelete` check** (shows buttons only for admin/subadmin):
  - `estimate.jsx` — Edit button wrapped with `canEditDelete`
  - `quotation.jsx` — Edit + Delete buttons wrapped with `canEditDelete`
  - `contract.jsx` — Edit + Delete buttons wrapped with `canEditDelete`
  - `invoice.jsx` — Edit + Delete buttons wrapped with `canEditDelete`
  - `clients.jsx` — Edit button in list + detail modal, Delete button wrapped with `canEditDelete`
  - `products.jsx` — Delete button wrapped with `canEditDelete`
  - `amc.jsx` — Delete buttons for both contracts and services wrapped with `canEditDelete`
  - `task.jsx` — already had role checks (verified)
  - `field.jsx` — already had role checks (verified)
- **Pattern used**: `const canEditDelete = userRole === "admin" || userRole === "subadmin"`
- **Rolling back**: Removing the conditional wrappers from any button would make it visible to all roles.

> *Done by ananth-dev* - Should a tooltip explain why buttons are hidden for employees?

---

### 25. Task Description Field (`backend/routes/taskRoutes.js`, `frontend/src/pages/task.jsx`)

Tasks needed a description field to capture detailed task information.

- **What was added**:
  - `task_description TEXT` column added to tasks table (via auto-migration)
  - Backend routes updated to include `task_description` in INSERT and UPDATE queries
  - Frontend task form added description textarea input
  - Task detail modal displays description with proper formatting
  - Priority validation added (safe default "Medium" on invalid input)
- **Files modified**: `backend/routes/taskRoutes.js`, `frontend/src/pages/task.jsx`
- **Rolling back**: Removing `task_description` from queries and form fields would revert to the original task system.

> *Done by ananth-dev* - Should task description support rich text formatting?

---

### 26. Target Auto-Creation Fix (`backend/routes/taskRoutes.js`)

Target updates were failing when no target record existed for an employee.

- **What was addressed**:
  - Target update endpoint now auto-creates default target (monthly: 0, calls: 0, visits: 0) if none exists before updating
  - Graceful error recovery on task priority (defaults to "Medium")
- **Rolling back**: Removing the auto-creation logic from the target update endpoint would revert to failing on missing target records.

> *Done by ananth-dev* - Should default targets be configurable per employee?

---

### 27. Call Report Service Types Fix (`backend/routes/callReportRoutes.js`, `frontend/src/pages/callreport.jsx`)

Call report service types needed to match the expected service types (Warranty/Installation/Service Call) with conditional Cost Breakdown and Payment Status fields.

- **What was fixed**:
  - Service type values normalized to match expected enums
  - Cost Breakdown section shown only for "Service Call" type
  - Payment Status shown only for "Service Call" and "Installation" types
- **Rolling back**: Reverting the conditional rendering in callreport.jsx and removing type normalization in callReportRoutes.js would return to the previous behavior.

> *Done by ananth-dev* - Should additional service types be added?

---

### 28. Products/Service Image Upload Fix (`backend/routes/serviceRoutes.js`)

Image upload was failing for products/services due to missing multipart header handling and empty image values.

- **What was fixed**:
  - Service routes now handle empty image values gracefully
  - Multipart form-data header explicitly set for upload requests
  - `backend/uploads/` folder created for service image storage
- **Rolling back**: Removing the empty check and explicit header setting would revert to the broken upload behavior.

> *Done by ananth-dev* - Should image compression be added for large uploads?

---

### 29. Clients Page Modern UI (`frontend/src/pages/clients.jsx`)

The clients page received a comprehensive UI overhaul with new fields and stats display.

- **What was updated**:
  - New fields: source, customer type (Individual/Company), GST number, industry, company size
  - Stats row at top: Total Clients, Active, New This Month, With Contracts
  - Modern card-based layout with search and filter
  - Client details modal with full information display
  - Commented out Excel download button (pending library installation)
- **Rolling back**: Reverting to the previous table-based layout would undo the UI modernization.

> *Done by ananth-dev* - Should client categories/tags be added for filtering?

---

## Permission Matrix

| Action | Employee | Sub-Admin | Admin |
|--------|----------|-----------|-------|
| View Records | ✅ | ✅ | ✅ |
| Create Records | ✅ | ✅ | ✅ |
| Edit Records | ❌ | ✅ | ✅ |
| Delete Records | ❌ | ✅ | ✅ |
| Assign Tasks | ❌ | ✅ | ✅ |
| Change User Role | ❌ | ❌ | ✅ |
| User Management | ❌ | ❌ | ✅ |

---

## API Endpoints Summary (RBAC)

| Endpoint | Method | Access |
|----------|--------|--------|
| `/api/auth/create-user` | POST | Admin only |
| `/api/auth/update-user/:id` | PUT | Admin only |
| `/api/auth/change-role/:id` | PUT | Admin only |
| All other CRUD routes | PUT/DELETE | Admin + Sub-Admin |
| All GET routes | GET | All authenticated users |

---

## ESLint Warning Fixes — Zero-Warning Build (Phase 4 - Code Quality)

### Overview
Fixed all ESLint `no-unused-vars` and `react-hooks/exhaustive-deps` warnings across 9 frontend files without removing any functionality. All unused imports, variables, and functions were properly removed or utilized. Corrupted edits from initial attempts were repaired to restore full compilation.

---

### 30. Unused Import & Variable Cleanup (9 Files)

Multiple files had imported icons, utilities, and declared variables that were never used, causing ESLint warnings during build.

- **Files modified**:
  - `frontend/src/components/ClientSearchDropdown.jsx` — Removed unused `Mail` icon import
  - `frontend/src/components/invoicetemplate.jsx` — Removed unused `BANK_DETAILS`, `Card`, `LogoSVG`, `HeaderWaves` definitions
  - `frontend/src/pages/callreport.jsx` — Removed unused `AlertCircle`, `Eye`, `ArrowRight`, `TrendingUp` imports; removed unused `selectedContract`, `reports`, `performance`, `totalUsed` variables
  - `frontend/src/pages/clients.jsx` — Removed unused `FileText`, `Users`, `UserCheck`, `Calendar`, `Hash`, `CreditCard` imports; removed unused `downloadExcel` function
  - `frontend/src/pages/estimateinvoice.jsx` — Removed unused `PlusCircle`, `ChevronDown` imports; removed unused `calculateTotals`, `html2pdf`, `INDIAN_STATES`, `GST_STATE_MAP`, `showAddAddress`, `handleAddAddress`, `handleDeleteAddress`, `historySelectedId`; added `eslint-disable-next-line` for useEffect dependency array
  - `frontend/src/pages/performainvoice.jsx` — Removed unused `PlusCircle`, `ChevronDown`, `calculateTotals`, `html2pdf`, `handleDeleteAddress`, `handleDescInput`, `addItem`; restored `BRANCH_DATA`/`BRANCH_OPTIONS` imports; restored `showAddAddress` state
  - `frontend/src/pages/products.jsx` — Added `fetchServices` to useEffect dependency array
  - `frontend/src/pages/quotation.jsx` — Removed unused `historySelectedId`, `historySearch`; added `eslint-disable-next-line` for useEffect dependency array
  - `frontend/src/pages/serviceestimation.jsx` — Removed unused `PlusCircle`, `ChevronDown`, `calculateTotals`, `html2pdf`, `handleDeleteAddress`, `handleDescInput`, `addItem`, `historySelectedId`; restored `BRANCH_DATA`/`BRANCH_OPTIONS` imports

- **Key approach**:
  - Removed only imports/variables that were genuinely unused (not referenced anywhere in the component)
  - Preserved all functionality — no features were removed
  - Used `// eslint-disable-next-line react-hooks/exhaustive-deps` for useEffect hooks where adding dependencies would cause infinite loops
  - Fixed corrupted edits from initial batch operations (duplicate imports, missing function names, broken JSX)

- **Rolling back**: Re-adding the removed imports and variable declarations would restore the warnings.

> *Done by ananth-dev* - Should a pre-commit ESLint check be added to prevent future warnings?

---

## Employee Task & Target UI Improvements (Phase 5 - UX Polish)

### Overview
Improved the employee experience on the `/dashboard/task` page by enhancing task action buttons and redesigning the target card to be horizontal and compact, matching the overall task card layout.

---

### 31. Employee Task Button Enhancements (`frontend/src/pages/task.jsx`)

Task action buttons for employees needed better visibility and interaction feedback.

- **What was addressed**:
  - **Accept button** (for "New" tasks): Changed from mint background with green text to solid green (`N.green`) background with white text
  - **Mark Done button** (for "Process" tasks): Changed from lavender background with primary text to solid primary (`N.primary`) background with white text
  - Added `hover:shadow-md` and `active:scale-95` transition effects for better interaction feedback
  - Increased padding from `px-2 py-1` to `px-3 py-1.5` for better clickability
  - Changed border radius from `rounded` to `rounded-lg` for consistency
  - Removed unnecessary `setNewStatus` calls that were redundant with direct `updateStatus` calls
  - Completed status badge also updated to `rounded-lg` with `font-semibold`

- **Rolling back**: Reverting button styles to use `N.mint`/`N.lavender` backgrounds with colored text would restore the original appearance.

> *Done by ananth-dev* - Should task buttons show loading states during API calls?

---

### 32. Employee Target Card Horizontal Redesign (`frontend/src/pages/task.jsx`)

The EmployeeTargetCard was displaying as a vertical stack of cards which looked unaligned and inconsistent with the task card layout.

- **What was addressed**:
  - **Main card layout**: Changed from vertical grid to horizontal flex layout (`flex-col md:flex-row`)
  - **Three-section horizontal layout**:
    - Left: Target info with icon (25% width)
    - Middle: Stats grid - Achieved, Remaining, Progress (flex-1)
    - Right: Progress bar + "Add Achievement" button (25% width)
  - **Collapsible achievement form**: Form now hidden by default, toggled via "Add Achievement" button
  - **Compact history table**: Reduced from 6 entries to 3 recent entries with smaller text (`text-xs`)
  - **Design token consistency**: All hardcoded colors replaced with `N.*` design tokens
  - **State management**: Added `showForm` state to control form visibility
  - **Form submission**: Form auto-hides after successful submission

- **Layout structure**:
  ```
  ┌─────────────────────────────────────────────────────────────┐
  │ [Icon] Monthly Target    │ Achieved │ Remaining │ Progress │ │
  │ ₹50,000                  │ ₹30,000  │ ₹20,000   │ 60%      │ │
  │                          │ [Progress Bar] [Add Achievement] │ │
  └─────────────────────────────────────────────────────────────┘
  ```

- **Rolling back**: Reverting to the vertical grid layout with separate cards for each metric would restore the original appearance.

> *Done by ananth-dev* - Should target cards support drag-to-reorder or custom layouts?

---

## Call Report Advanced Features (Phase 6 - Enhanced Reporting)

### Overview
Completely rebuilt the Call Report page with advanced form features: searchable customer auto-fill from AMC/ALC contracts, start/end time tracking with duration overflow calculation, petrol/km inputs, and improved UI/UX. Updated backend routes and database schema to support all new fields.

---

### 33. Customer Search & Contract Auto-Fill (`frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`)

Customer name needed to be searchable with auto-fill capability from existing AMC/ALC contracts instead of manual text entry.

- **What was added**:
  - **Customer Search Endpoint**: `GET /api/call-reports/customers?q=...` searches `clients` table by name, phone, or company name
  - **Contract Lookup Endpoint**: `GET /api/call-reports/contracts/:type` fetches AMC/ALC contracts with title, client company, mobile, location, amount, and remaining value
  - **SearchableSelect Component**: Enhanced dropdown with live server-side search, loading states, and auto-fill capability
  - **Contract Auto-Fill**: When selecting AMC/ALC call type, a contract dropdown appears that auto-fills customer name, mobile number, and location/city
  - **Customer Auto-Fill**: Selecting a customer from search auto-fills mobile and location fields

- **Files modified**: `frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`
- **Rolling back**: Reverting to simple text input for customer name and removing the contract lookup endpoint would undo this feature.

> *Done by ananth-dev* - Should customer search also include contract history?

---

### 34. Time Tracking & Duration Overflow (`frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`)

Call reports needed start/end time tracking with automatic duration calculation and visual overflow alerts when actual time exceeds contract limits.

- **What was added**:
  - **Start/End Time Inputs**: HTML time inputs for recording call start and end times
  - **Real-time Duration Calculation**: Frontend calculates actual duration in minutes as times are entered
  - **Duration Overflow Alert**: Visual indicator (red background + AlertTriangle icon) when actual duration exceeds the contract's duration limit, showing overflow minutes (e.g., "+15 min")
  - **Duration Display Card**: Green card showing duration vs limit when within bounds, red card when exceeded
  - **Backend Duration Logic**: Server-side calculation of `actual_duration`, `assigned_time`, and `is_exceeded` flag on save
  - **Table Duration Column**: Shows duration with "(+)" indicator for exceeded calls

- **Database columns added**:
  - `assigned_time INT DEFAULT 30` — expected duration in minutes
  - `actual_duration INT DEFAULT 0` — calculated actual duration
  - `is_exceeded TINYINT(1) DEFAULT 0` — flag for overflow
  - `duration_limit INT DEFAULT NULL` — contract-specific limit

- **Files modified**: `frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`, `backend/config/database.js`
- **Rolling back**: Removing time inputs and duration calculation logic would revert to the previous behavior.

> *Done by ananth-dev* - Should duration limits be configurable per engineer or call type?

---

### 35. Expense Tracking — Petrol, KM, Spare Parts, Labour (`frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`)

Call reports needed expense tracking for field service visits including travel and parts costs.

- **What was added**:
  - **Kilometers Input**: Numeric field for distance traveled
  - **Petrol Charges**: Currency input for fuel costs
  - **Spare Parts**: Currency input for parts used
  - **Labour Charges**: Currency input for labor costs
  - **Auto-calculated Total**: Backend calculates `total_expenses = petrol + spare_parts + labour`
  - **Table Integration**: KM and Total columns added to main table
  - **Expanded Row Details**: Full expense breakdown in expandable row view

- **Files modified**: `frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`
- **Rolling back**: Removing expense input fields and total calculation would undo this feature.

> *Done by ananth-dev* - Should expense reports be generated per engineer or per month?

---

### 36. Database Schema Expansion (`backend/config/database.js`)

The `call_reports` table needed significant schema expansion to support all new features.

- **What was added** (CREATE TABLE updated + migrations):
  - `call_id VARCHAR(20)` — human-readable call ID
  - `session_id VARCHAR(50)` — session grouping for batch saves
  - `client_name`, `staff_name`, `executive_name` — normalized name fields
  - `phone`, `location` — contact and location fields
  - `call_sequence INT DEFAULT 1` — ordering within session
  - `report_date DATE` — date of the call report
  - `complaint TEXT` — issue description
  - `priority ENUM('Critical', 'High', 'Medium')` — priority level
  - `call_type VARCHAR(50)` — AMC/ALC/Paid/Warranty/etc.
  - `payment_type VARCHAR(50)` — Cash/Card/Credit/Cheque/UPI
  - `invoice_value DECIMAL(10,2)` — billed amount
  - `payment_status VARCHAR(50)` — Collected/Pending
  - `assigned_time`, `actual_duration`, `is_exceeded`, `duration_limit` — time tracking
  - `km`, `petrol_charges`, `spare_parts_price`, `labour_charges`, `total_expenses` — expense tracking

- **Contract table migrations added**:
  - `client_company VARCHAR(200)` — for contract display
  - `amount_value DECIMAL(10,2)` — contract value
  - `remaining DECIMAL(10,2)` — remaining contract balance

- **Files modified**: `backend/config/database.js`
- **Rolling back**: Removing the new column definitions from `ensureTablesAndColumns()` would prevent auto-migration of these fields.

> *Done by ananth-dev* - Should a separate expenses table be created for detailed line items?

---

### 37. Enhanced Table & Stats Display (`frontend/src/pages/callreport.jsx`)

The call report table and stats cards were redesigned to display the new data fields effectively.

- **What was updated**:
  - **New Stats Card**: "Exceeded" stat showing count of calls that exceeded duration limits
  - **Table Columns**: Added Mobile, Location, Time, Duration, KM, Total columns
  - **Duration Badges**: Green badges for within-limit calls, red badges for exceeded calls with "(+)" indicator
  - **Time Display**: Shows "HH:MM - HH:MM" format in table
  - **Expanded Details View**: 5-column grid showing all fields including time tracking, expense breakdown, and remarks
  - **CSV Export Updated**: Includes all new fields in export

- **Files modified**: `frontend/src/pages/callreport.jsx`
- **Rolling back**: Reverting table columns and stats to the previous layout would undo these changes.

> *Done by ananth-dev* - Should a dedicated performance dashboard be created for engineer metrics?

---

### 38. Performance Stats Endpoint (`backend/routes/callReportRoutes.js`)

Backend needed an endpoint to calculate staff performance metrics based on call data.

- **What was added**:
  - `GET /api/call-reports/performance` — returns per-staff metrics:
    - `total_calls` — total number of calls
    - `exceeded_calls` — calls that exceeded duration limit
    - `total_duration` — sum of all actual durations
    - `total_assigned_time` — sum of all assigned times
    - `performance_rating` — percentage of calls completed within time limit

- **Files modified**: `backend/routes/callReportRoutes.js`
- **Rolling back**: Removing the performance route would undo this endpoint.

> *Done by ananth-dev* - Should performance data be visualized with charts?

---

## AMC Contract Creation Fix & Target/Achievement System (Phase 7 - Core Fixes)

### Overview
Fixed the contract creation error ("Client company, contract title, amount, and service type are required") caused by JavaScript falsy-check validation not handling empty strings. Also implemented full carry-forward persistence, effective target calculation, and balance target display in the admin and employee views with auto carry-forward on month change.

---

### 39. AMC Contract Creation Error Fix (`backend/routes/contract.js`)

Contract creation was failing because the validation checked `!amount_value` which fails on `0` (a valid amount) and empty strings.

- **What was fixed**:
  - Changed validation from `!amount_value` to `isNaN(parsedAmount) || parsedAmount < 0` using `parseFloat()`
  - Trimmed all string fields (`client_company`, `contract_title`, `service_type`) before validation
  - Added `email` field to INSERT and UPDATE queries
  - Backend now returns proper error messages with specific field requirements

- **Files modified**: `backend/routes/contract.js`
- **Rolling back**: Reverting to the original `!amount_value` check would restore the broken validation.

> *Done by ananth-dev* - Should we add a "contract value must be > 0" minimum validation?

---

### 40. AMC Contract Form Client-Side Validation (`frontend/src/pages/amc.jsx`)

The frontend wasn't sending `amount_value` as a proper number, causing the backend to reject it.

- **What was fixed**:
  - Added client-side validation: checks for empty client_company, contract_title, and invalid amount_value
  - Converts `amount_value` to `parseFloat()` before sending to backend
  - Sends `null` for optional fields (mobile_number, location_city, email) instead of empty strings
  - Added proper trimming of company and title before submission

- **Files modified**: `frontend/src/pages/amc.jsx`
- **Rolling back**: Removing the client-side validation and parseFloat conversion would revert to the previous behavior.

> *Done by ananth-dev* - Should the form validate contract title uniqueness?

---

### 41. Target Carry-Forward Persistence (`backend/routes/taskRoutes.js`)

The `carry_forward` value was calculated but never saved to the database. It was only computed in-memory per request.

- **What was fixed**:
  - All three GET target endpoints (`/targets`, `/targets/my`, `/targets/user`) now persist `carry_forward` and `effective_target` to the `task_targets` table
  - `processAchievement()` now calls `UPDATE task_targets SET carry_forward = ?, effective_target = ?` after each achievement update
  - `carry_forward = monthly_target - prev_month_achieved_amount` (using `achieved_amount`, not `achieved_count`)
  - `effective_target = monthly_target + carry_forward`
  - All endpoints now return `balance_target = Math.max(0, effective_target - achieved_amount)`

- **Database columns used**:
  - `task_targets.carry_forward DECIMAL(15,2) DEFAULT 0`
  - `task_targets.effective_target DECIMAL(15,2) DEFAULT 0`

- **Files modified**: `backend/routes/taskRoutes.js`
- **Rolling back**: Removing the `UPDATE task_targets SET carry_forward = ?, effective_target = ?` calls would revert to in-memory-only carry-forward.

> *Done by ananth-dev* - Should carry-forward be capped at a maximum value?

---

### 42. Admin Target Page — Balance Target Display (`frontend/src/pages/task.jsx`)

Admin's target cards in the "Targets" tab weren't showing the effective target, carry-forward, balance, or achieved amounts correctly.

- **What was added**:
  - **Carry Forward row**: Shows orange-colored carry-forward amount when `carry_forward > 0`
  - **Effective Target row**: Shows the combined target (monthly + carry-forward) in primary color
  - **Achieved row**: Shows achieved amount in green
  - **Balance row**: Shows remaining balance in red (₹0 shown in green when target met)
  - **Progress bar**: Now uses effective target (not just monthly) for percentage
  - **Progress text**: Shows "₹achieved / ₹effective (pct%)"

- **Target History drill-in table** (admin): Added columns:
  - `Carry Fwd` — carry-forward amount in orange
  - `Effective` — effective target in primary blue
  - `Balance` — remaining balance (green if 0, red otherwise)
  - `Achieved` — achieved amount in green

- **Files modified**: `frontend/src/pages/task.jsx`
- **Rolling back**: Reverting the target card JSX and history table columns would restore the simple progress display.

> *Done by ananth-dev* - Should admins be able to manually adjust carry-forward amounts?

---

### 43. Employee Target Card — Enhanced Display (`frontend/src/pages/task.jsx`)

The employee target card now properly shows all target metrics with effective target calculation.

- **What was updated**:
  - **Left section**: Shows monthly target + carry-forward indicator (orange text) below the amount
  - **Stats grid**: Changed from 3 columns to 4 columns:
    - Effective (primary blue) — the total target (monthly + carry-forward)
    - Achieved (green) — amount achieved this month
    - Balance (red/green) — remaining amount
    - Progress (colored by %) — percentage completed
  - **Progress bar**: Uses effective target for width calculation
  - Fixed `achieved_amount` to use the backend field directly (removed fallback to `achieved_count`)

- **Files modified**: `frontend/src/pages/task.jsx`
- **Rolling back**: Reverting the stats grid changes would restore the 3-column layout.

> *Done by ananth-dev* - Should the card show a "Target Completed!" celebration animation at 100%?

---

### 44. Auto Carry-Forward on Admin Targets List (`backend/routes/taskRoutes.js`)

When an admin views the targets list, any targets that haven't had their carry-forward calculated this month are automatically updated.

- **What was added**:
  - `GET /targets` (admin) now runs `Promise.all` across all targets
  - For each target: queries previous month's `achieved_amount`, calculates carry-forward, and persists to DB
  - Sets `pending_amount` and `balance_target` fields on each row
  - Added `balance_target` to history entries as well

- **Files modified**: `backend/routes/taskRoutes.js`
- **Rolling back**: Removing the `Promise.all(carryForwardChecks)` logic would stop auto carry-forward on admin view.

> *Done by ananth-dev* - Should auto carry-forward run on a scheduled basis instead of on admin page view?

---

### 45. Database Migration — Contracts Email + Carry-Forward (`backend/config/database.js`)

Added missing database column migrations for the contracts table and confirmed task_targets carry_forward/effective_target columns.

- **What was added**:
  - `contracts.email VARCHAR(150) DEFAULT NULL` — for contract contact email
  - `task_targets.carry_forward DECIMAL(15,2) DEFAULT 0` — confirmed in auto-migration
  - `task_targets.effective_target DECIMAL(15,2) DEFAULT 0` — confirmed in auto-migration
  - `contracts.client_company VARCHAR(200)` — confirmed
  - `contracts.amount_value DECIMAL(10,2) DEFAULT 0` — confirmed
  - `contracts.remaining DECIMAL(10,2) DEFAULT 0` — confirmed

- **Files modified**: `backend/config/database.js`
- **Rolling back**: Removing the migration entries would prevent auto-addition of these columns on existing databases.

> *Done by ananth-dev* - Should we add an index on task_targets.user_name for faster lookups?

---

## Quotation Save 500 Error Fix (Phase 8 - Bug Fixes)

### Overview
Fixed the "Error saving Quotation: Request failed with status code 500" error by adding proper error logging, fixing null/undefined handling in item data, and removing an overly strict mobile number validation check.

---

### 46. Quotation Save 500 Error — Root Causes (`backend/routes/quotationRoutes.js`)

Three issues were causing 500 errors when saving quotations:

- **Issue 1**: No error logging — SQL errors were swallowed and returned as 500 with no details
- **Issue 2**: Item description field — frontend sends items as `item.name` but validation checked `item.description`, causing validation failure
- **Issue 3**: Mobile number required — removed mobile number from being required in validation (was causing 400 errors that manifested as 500 in some cases)

- **What was fixed**:
  - Added `console.error` logging at customer INSERT, quotation INSERT, and version INSERT error points
  - Changed validation to accept both `item.description` and `item.name` as the description field
  - Removed `!c.mobile_number` validation check
  - Added fallback for item fields: `item.description || item.name || ""`, `item.tax || 0`, `item.discount || 0`, `item.subtotal || 0`
  - Fixed client INSERT/UPDATE to log errors without rolling back the main transaction
  - Error messages now return specific SQL error text for easier debugging

- **Files modified**: `backend/routes/quotationRoutes.js`
- **Rolling back**: Removing the error logging and null handling fallbacks would revert to the previous behavior.

> *Done by ananth-dev* - Should we add a client-side validation summary before form submission?

---

## Service Estimation Full Flow Fix (Phase 9 - Document Pipeline)

### Overview
Fixed the entire Service Estimation flow — from form creation through PDF generation, email sending, and HTML download. Multiple bugs were preventing proper data sync, tax calculation, document rendering, and type mapping across the pipeline.

---

### 47. Service Estimation Form — Data Sync & Error Handling (`frontend/src/pages/serviceestimation.jsx`)

The service estimation form had several issues with data flow between customer selection, client details, and form submission.

- **What was fixed**:
  - **`handleSelectProposal`**: Fixed field mapping to include `client_country`, added null-safe defaults for all fields, proper `Number()` coercion for item prices/quantities/tax
  - **`handleEdit`**: Added try/catch error handling, null-safe field mapping for all 25+ fields, proper JSON parsing for `terms_separate_orders` with fallback, added `custom_terms` field
  - **`handleSubmit`**: Changed from spreading `customer` reference to explicit field mapping (prevents stale data), added `client_city` fallback to `location_city`, improved error messages showing backend response details
  - **Validation**: Added `customer.customer_name` required check before submission

- **Files modified**: `frontend/src/pages/serviceestimation.jsx`
- **Rolling back**: Reverting the handler functions to use spread operators and remove null-safe defaults would restore the previous broken behavior.

> *Done by ananth-dev* - Should a draft/auto-save feature be added for long forms?

---

### 48. Service Estimation — Tax Calculation Fix (`frontend/src/pages/serviceestimation.jsx`)

The `getTaxCalculations()` function was failing when items had `quantity` instead of `qty` field, and wasn't properly coercing numeric values.

- **What was fixed**:
  - Added fallback: `Number(item.qty || item.quantity || 0)` for quantity
  - Added `Number()` coercion for `price`, `discount`, and `tax` fields
  - CGST/SGST calculation for same-state (branch state vs client state comparison)
  - IGST calculation for inter-state transactions
  - Tax-exempt mode (`terms_tax` checkbox) now correctly returns zero tax values

- **Tax logic**:
  ```
  Same state (e.g., Tamil Nadu → Tamil Nadu): CGST + SGST (split equally)
  Different state (e.g., Tamil Nadu → Karnataka): IGST (full rate)
  Tax exempt (terms_tax checked): No tax applied
  ```

- **Files modified**: `frontend/src/pages/serviceestimation.jsx`
- **Rolling back**: Removing the `Number()` coercion and quantity fallback would restore the broken calculation.

> *Done by ananth-dev* - Should custom tax rates per item be supported?

---

### 49. PDF Type Mapping Fix (`backend/routes/unifiedInvoiceRoute.js`)

The PDF download endpoint had a typo in the type map that caused incorrect document labels.

- **What was fixed**:
  - Changed `"performa"` → `"proforma"` in `typeMap` object
  - This ensures PDFs render with correct "PROFORMA INVOICE" label instead of undefined behavior

- **Files modified**: `backend/routes/unifiedInvoiceRoute.js`
- **Rolling back**: Reverting to `"performa"` would break PDF label rendering.

> *Done by ananth-dev* - Should the type map be centralized in a shared config file?

---

### 50. PDF Generator — Alignment & Layout Fix (`backend/backendutil/generateInvoicePdf.js`)

The PDF generator was rewritten to exactly match the `form.html` template styling.

- **What was fixed**:
  - **CSS**: Complete rewrite using table-based layout (better Puppeteer rendering than grid/flex)
  - **Header**: Brand logo + document title with gradient top bar
  - **From/Billed To boxes**: Proper two-column layout with contact details
  - **Items table**: Split product name/specs at first comma (bold name, gray specs), proper column widths
  - **Terms & Conditions**: Proper `<ul>` list rendering with all term types
  - **Branches**: Dynamic display of other branches (excludes current supplier branch)
  - **Bank details**: Grid layout with labels and values
  - **Executive footer**: Name, phone, email in single row
  - **Watermark**: Logo overlay at 0.07 opacity
  - **Print margins**: Zero margin A4 with `print-color-adjust: exact`

- **Files modified**: `backend/backendutil/generateInvoicePdf.js`
- **Rolling back**: Reverting to the previous HTML template would restore the broken layout.

> *Done by ananth-dev* - Should multi-page PDF support be added for long item lists?

---

### 51. Email Template — Terms & Branches Addition (`backend/backendutil/generateEmailHtml.js`)

The email template was missing terms & conditions and branches sections.

- **What was added**:
  - **Terms section**: Dynamic rendering of all term types (general, tax, project period, validity, separate orders, payment, warranty, custom)
  - **Branches section**: Shows other branches with address and GSTIN
  - **Item rendering**: Split product name/specs at first comma (matches PDF)
  - **Client country**: Added to billed-to address display

- **Files modified**: `backend/backendutil/generateEmailHtml.js`
- **Rolling back**: Removing the terms and branches sections would revert to the simpler email body.

> *Done by ananth-dev* - Should email templates support custom branding per branch?

---

### 52. HTML Download Utility — Verified (`frontend/src/utils/downloadHtml.js`)

The HTML download utility was verified to work correctly with service estimation data.

- **Verified**:
  - Type map includes `"service": { label: "SERVICE ESTIMATION", prefix: "SE" }`
  - Uses `h.invoice_id` (matches backend response field)
  - Proper tax rate detection (`custom_tax`, `tax_type` handling)
  - Branch data lookup with fallback to Coimbatore
  - Terms rendering from all term fields

- **No changes needed** — utility was already functional.

---

### 53. Invoice Preview Component — Verified (`frontend/src/components/invoicetemplate.jsx`)

The React invoice preview component was verified to work correctly with service type.

- **Verified**:
  - Route map: `service → "service-estimation"` (correct API endpoint)
  - Type map: `service → { label: "SERVICE ESTIMATION", prefix: "SE" }`
  - Uses `h.invoice_id` (matches backend `SELECT t.id AS invoice_id`)
  - Proper bank/branch/executive data resolution
  - Terms parsing with JSON handling for `terms_separate_orders`

- **No changes needed** — component was already functional.

---

### Service Estimation Flow Summary

```
Create Form (serviceestimation.jsx)
    ↓
POST /api/service-estimation/create
    ↓
Database: service_estimations + service_estimation_items
    ↓
List View → Select → Double-click Preview
    ↓
Invoice Component (invoicetemplate.jsx) — React preview
    ↓
├── Download PDF → /api/service-estimation/download-pdf/:id
│       → Puppeteer renders HTML → A4 PDF
├── Download HTML → downloadAsHtml() → Blob download
└── Send Email → /api/service-estimation/send-email/:id
        → HTML body (generateEmailHtml) + PDF attachment
```

### Document Type Mapping

| Type | Prefix | Label | API Route |
|------|--------|-------|-----------|
| Quotation | QT | QUOTATION | `/api/quotations` |
| Proforma | PI | PROFORMA INVOICE | `/api/performainvoice` |
| Estimation | EI | ESTIMATION | `/api/estimate-invoice` |
| Service | SE | SERVICE ESTIMATION | `/api/service-estimation` |

---

*Document updated by ananth-dev*

---

## Call Report Two-Step Form, Modal Responsive Fixes & Search Fix (Phase 10 - UX & Data)

### Overview
Implemented a two-step call report form (Step 1: basic info, Step 2: engineer/expenses), fixed all modals to be responsive on mobile with sticky headers, and resolved "No results" issues for customer/contract search by querying both `clients` and `customers` tables.

---

### 54. Two-Step Call Report Form (`frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`)

The call report form was split into two steps for faster initial entry and later completion.

- **What was added**:
  - **Step 1 (New Service Call)**: 11 required fields — customer name, mobile, location, call type, duration, priority, call referrer, call details, status, payment type, invoice value, payment status
  - **Step 2 (Complete Call Details)**: Opens on double-click or "Complete" button — engineer assignment, start/end time, KM, petrol, spare parts, labour charges, remarks
  - **`step2_completed` column**: `TINYINT(1) DEFAULT 0` — tracks whether Step 2 is done
  - **Table "Completion" column**: Shows "Basic" (Step 1 only) vs "Complete" (Step 2 done)
  - **Separate state**: `basicForm` for Step 1, `step2Form` for Step 2, `form` for full edit
  - **Backend POST**: Creates with `step2_completed=0`
  - **Backend PUT**: Handles both full edit and Step 2 partial update, sets `step2_completed=1` when engineer assigned
  - **`GET /:id`**: New endpoint for fetching single call report to prefill Step 2

- **Database columns added**:
  - `call_reports.call_referrer VARCHAR(150)` — who referred the call
  - `call_reports.step2_completed TINYINT(1) DEFAULT 0` — Step 2 completion flag

- **Files modified**: `frontend/src/pages/callreport.jsx`, `backend/routes/callReportRoutes.js`, `backend/config/database.js`
- **Rolling back**: Removing the two-step form logic and reverting to single form would undo this feature.

> *Done by ananth-dev* - Should Step 2 be mandatory before a certain deadline?

---

### 55. Modal Responsive Fixes — Sticky Headers & Mobile Width (`frontend/src/pages/callreport.jsx`)

All three modals (Step 1, Edit, Step 2) had overflow issues on mobile screens.

- **What was fixed**:
  - **Wrapper**: Changed from `flex items-center justify-center p-3 sm:p-4 overflow-y-auto` to `flex justify-center overflow-y-auto pt-4 pb-4` — prevents centering overflow on small screens
  - **Modal width**: Changed from `w-full max-w-3xl` to `w-[95%] max-w-3xl` — ensures proper padding on mobile
  - **Sticky headers**: All modal headers use `sticky top-0 z-20` to stay visible while scrolling
  - **Scrollable content**: Form content uses `max-h-[calc(90vh-80px)] overflow-y-auto` for independent scrolling
  - **Applied to**: Step 1 modal, Edit modal, Step 2 modal

- **Files modified**: `frontend/src/pages/callreport.jsx`
- **Rolling back**: Reverting modal wrapper classes would restore the overflow issue.

> *Done by ananth-dev* - Should modals support swipe-to-dismiss on mobile?

---

### 56. Customer & Contract Search Fix (`backend/routes/callReportRoutes.js`, `frontend/src/pages/callreport.jsx`)

Customer and contract dropdowns were showing "No results" because the search only queried the `clients` table (populated from lead conversions) and missed the `customers` table (used by invoices/quotations).

- **What was fixed**:
  - **Customer search**: Now queries both `clients` AND `customers` tables using `UNION ALL`
    - `clients`: searches by `name`, `phone`, `company_name`, `email`
    - `customers`: searches by `customer_name`, `mobile_number`, `email`
  - **Contract search**: Now includes contracts with `contract_type = 'Service'` in addition to exact type match (AMC/ALC)
  - **Step 1 contract fix**: Added `searchBasicContracts` function and `basicContractSearchResults` state — Step 1 was incorrectly using shared `contractSearchResults` state
  - **Column fixes**: Fixed `customer_name` → `name` for `clients` table, removed non-existent `duration_limit` from contract query
  - **Sample data**: Created `seed-sample-data.js` with 8 sample clients and 6 sample contracts (4 AMC, 2 ALC)

- **Test results**:
  - 19 customers found (8 sample + 11 existing)
  - 7 AMC contracts found
  - 4 ALC contracts found

- **Files modified**: `backend/routes/callReportRoutes.js`, `frontend/src/pages/callreport.jsx`
- **Files created**: `backend/seed-sample-data.js`
- **Rolling back**: Reverting to single-table customer query would restore the "No results" issue.

> *Done by ananth-dev* - Should customer search include fuzzy matching for typos?

---

### 57. PDF Layout Fixes — 2x2 Grid & Fixed Summary Box (`backend/backendutil/generateInvoicePdf.js`, `backend/backendutil/generateEmailHtml.js`, `frontend/src/utils/downloadHtml.js`)

The PDF summary boxes were not maintaining fixed sizes and the layout was inconsistent.

- **What was fixed**:
  - **4-box layout**: Changed from table-cells to CSS Grid (`grid-template-columns: 1fr 1fr`) for consistent 2x2 layout
  - **Summary box**: Uses `table-layout: fixed` + `min-height` to maintain fixed size after download
  - **Branches**: Shows other 2 branches at bottom of PDF
  - **Email & HTML templates**: Updated to match PDF layout exactly

- **Files modified**: `backend/backendutil/generateInvoicePdf.js`, `backend/backendutil/generateEmailHtml.js`, `frontend/src/utils/downloadHtml.js`
- **Rolling back**: Reverting to table-cell layout would restore the broken box sizing.

> *Done by ananth-dev* - Should PDF support custom branding per company?

---

### Architecture Update — Call Report Data Flow

```
Step 1 Form (basicForm)
    ↓ POST /api/call-reports
    ↓ step2_completed = 0
Table shows "Basic"
    ↓ Double-click or "Complete" button
Step 2 Form (step2Form)
    ↓ PUT /api/call-reports/:id
    ↓ step2_completed = 1 (when engineer assigned)
Table shows "Complete"
```

### Search Data Sources

| Dropdown | Tables Queried | Search Fields |
|----------|---------------|---------------|
| Customer | `clients` + `customers` | name, phone, company_name, email, customer_name, mobile_number |
| Contract (AMC) | `contracts` | contract_type = 'AMC' OR 'Service' |
| Contract (ALC) | `contracts` | contract_type = 'ALC' OR 'Service' |

---

*Document updated by ananth-dev*
