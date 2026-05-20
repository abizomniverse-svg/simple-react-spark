# Call Report Page - Complete Refactor Plan

## Current Issues
1. Form 1 and Form 2 are not properly separated in terms of editability
2. No session-based multiple call tracking (Call-1, Call-2, Call-3)
3. Edit modal mixes both forms without clear lock/unlock behavior
4. Users can re-edit Form 1 after it should be locked
5. No visual grouping of calls by session

## Architecture Changes

### Data Model (Already exists in DB, needs proper usage)
- `session_id` - Groups all calls under one service session
- `call_sequence` - Order of calls within a session (1, 2, 3...)
- `step2_completed` - Whether Form 2 details have been filled
- Form 1 fields: customer, mobile_number, location_city, call_type, call_details, priority, call_referrer, status, payment_type, invoice_value, payment_status, duration_limit
- Form 2 fields: engineer, start_time, end_time, km, petrol_charges, spare_parts_price, labour_charges, remarks

### Frontend Changes (`frontend/src/pages/callreport.jsx`)

#### New State Variables
```javascript
const [sessionCalls, setSessionCalls] = useState([]);        // All calls in current viewing session
const [viewingSessionId, setViewingSessionId] = useState(null); // Currently viewed session
const [isAddingCallToSession, setIsAddingCallToSession] = useState(false);
const [editingCallIndex, setEditingCallIndex] = useState(null);  // Which Form 2 call is being edited
const [basicFormLocked, setBasicFormLocked] = useState(false);   // Form 1 lock state
const [savedSessionId, setSavedSessionId] = useState(null);      // Session ID after Form 1 save
```

#### Flow Changes

**1. New Call Flow:**
- Click "New Call" → Opens Form 1 modal (basic info)
- Fill Form 1 → Submit → Saves to DB with `session_id = SES-{timestamp}`
- After save → Form 1 is LOCKED (cannot be edited again)
- User is prompted to "Add Call Details" (Form 2) or "Add Another Call"
- Form 2 opens → Fill engineer, times, expenses → Save as Call-1
- Can click "Add Another Call" → Form 2 opens again → Save as Call-2
- And so on: Call-3, Call-4...

**2. Viewing Existing Session:**
- Table shows grouped sessions (one row per session, not per call)
- Click session row → Expand to show all calls (Call-1, Call-2, etc.)
- Form 1 data shown as read-only card at top
- Form 2 calls shown as editable cards below

**3. Edit Permissions:**
- **Admin/Subadmin**: Can edit Form 2 calls, delete calls, add new calls to session
- **User/Employee**: Can only add new Form 2 calls to their sessions, cannot edit existing Form 2
- **Form 1**: NEVER editable after initial save (for any role)

#### UI Component Changes

**Table View:**
- Group by `session_id` instead of individual calls
- Each row represents one session
- Show: Session ID, Customer, Call Count (e.g., "3 calls"), Status summary, Total Value
- Expandable row showing all Form 2 calls (Call-1, Call-2, Call-3...)
- Each call card shows: Engineer, Time, Duration, Expenses, Status

**Form 1 Modal (Basic - One Time):**
- Same fields as current basic form
- After submit → modal closes, Form 1 locked
- Show success toast with "Add Call Details" button

**Form 2 Modal (Details - Re-editable):**
- Title: "Call-1", "Call-2", "Call-3" based on sequence
- Pre-filled info card from Form 1 (read-only)
- Fields: Engineer, Start Time, End Time, KM, Petrol, Spare Parts, Labour, Remarks, Status
- Save button → Updates/creates call record
- "Add Another Call" button → Opens fresh Form 2 for next sequence

**Session Detail View:**
- Read-only Form 1 summary card at top
- List of all Form 2 calls as cards
- Each call card has Edit (admin only) and Delete (admin only) buttons
- "Add Call" button at bottom (all users)

#### Backend Changes (`backend/routes/callReportRoutes.js`)

**1. GET /api/call-reports/sessions** (New endpoint)
- Returns grouped sessions with call counts
- Query: `SELECT session_id, MIN(customer_name) as customer, COUNT(*) as call_count, SUM(invoice_value) as total_value, GROUP_CONCAT(DISTINCT status) as statuses FROM call_reports GROUP BY session_id`

**2. GET /api/call-reports/session/:sessionId** (Already exists, keep)
- Returns all calls in a session ordered by call_sequence

**3. POST /api/call-reports** (Modify)
- When creating Form 1: Creates first record with `call_sequence = 1`, `step2_completed = 0`
- When adding Form 2 call: Finds max sequence in session, creates new record with `sequence + 1`

**4. PUT /api/call-reports/:id** (Modify - add permission check)
- Check if user is admin before allowing Form 2 edit
- If user is not admin, reject with 403

**5. DELETE /api/call-reports/:id** (Keep - admin only already)

#### Database Changes
- Migration already exists with `session_id`, `call_sequence`, `step2_completed` columns
- May need to add index on `session_id` for performance

### Implementation Steps

1. **Add new state variables** for session tracking
2. **Create session grouping logic** - transform flat calls array into sessions
3. **Update table** to show sessions instead of individual calls
4. **Create expandable session rows** showing all calls
5. **Modify Form 1 submit** to lock after save and redirect to Form 2
6. **Create Form 2 modal** with proper sequence numbering
7. **Add "Add Another Call" button** in Form 2
8. **Update backend routes** for session-based operations
9. **Add permission checks** for Form 2 edits
10. **Test full flow** end-to-end

### Key UX Improvements
- Clear visual distinction between Form 1 (locked) and Form 2 (editable)
- Session grouping makes it easy to see all related calls
- Call sequence numbering (Call-1, Call-2, Call-3) for clarity
- Admin vs User permissions clearly enforced
- Form 1 data always visible as reference when working on Form 2
