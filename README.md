# SPOTon Chat 💬 (Supabase Edition)

**"Connect. Chat. Stay in touch."**

SPOTon Chat is a modern, educational web-based messaging application built using **HTML5, CSS3, Vanilla JavaScript, and Supabase (PostgreSQL, Supabase Auth, Supabase Storage, Supabase Realtime, and Row Level Security)**.

It provides a lightweight messaging experience with 1-on-1 private conversations, message replies, read receipts (✓✓), BBM-style personal status updates, username rate-limiting (3 changes max with a 3-day cooldown), search discoverability privacy, and an unapproved-user 3-message gate.

---

## 📁 Project Structure

```
SPOTon/
├── index.html              # Main application entry point (Landing Page + Chat App UI)
├── schema.sql              # Complete PostgreSQL schema, RLS policies, triggers, and indexes
├── css/
│   ├── style.css           # Global typography, color variables, layout, responsive resets
│   ├── components.css      # Buttons, confirmation modals, toasts, landing page hero
│   ├── chat.css            # Conversation list, chat bubbles, replies, read ticks, 3-dot menu
│   └── status.css          # BBM-style status cards, feed, and profile settings
├── js/
│   ├── config.js           # Centralized configuration (Supabase URL, Anon Key, app rules)
│   ├── crypto.js           # PBKDF2 password hashing & token utilities via Web Crypto API
│   ├── supabaseClient.js   # Supabase client initializer with Realtime & local fallback
│   ├── presence.js         # Realtime presence channel, heartbeat, auto-ticking relative times
│   ├── auth.js             # Supabase Auth integration, username mapping, math CAPTCHA
│   ├── users.js            # User search (@username), Supabase Storage avatar upload, cooldown
│   ├── chat.js             # 1-on-1 messaging, replies, read ticks, Supabase Realtime, 3-msg rule
│   ├── status.js           # BBM-style personal status updates & live feed
│   ├── settings.js         # Privacy settings ('who_can_find_me', 'allow_message_requests')
│   └── app.js              # UI controller, event delegation, tabs & polling engine
├── assets/
│   ├── logo.svg            # SPOTon Chat modern vector logo
│   └── default-avatar.svg  # Vector default avatar placeholder
├── .env.example            # Sample environment variables for cloud deployment
└── README.md               # Complete setup, testing, and architecture guide
```

---

## 🚀 How to Run Locally (Instant Zero-Setup Mode)

SPOTon Chat includes an educational **Supabase local emulator mode** that requires zero installations. You can test it immediately without even creating a cloud account:

1. In Windows Explorer, open:
   `c:\Users\RU\Documents\pop\SPOTon`
2. **Double-click `index.html`** (or open in Chrome, Edge, or Firefox).
3. The application will launch instantly with pre-seeded demo accounts:
   - `@alvis` (Password: `password123`)
   - `@siti` (Password: `password123`)
   - `@budi` (Password: `password123`, 3/3 username changes used, 3-day cooldown active)

---

## ⚡ Connecting to Your Real Supabase Project

When you are ready to connect to a live Supabase project:

### Step 1: Create a Supabase Project
1. Visit [supabase.com](https://supabase.com/) and sign in.
2. Click **New Project**, name it (e.g. `spoton-chat`), choose a database password, and create the project.

### Step 2: Execute the Database Schema (`schema.sql`)
1. In your Supabase Dashboard, click the **SQL Editor** tab on the left sidebar.
2. Click **New query**.
3. Open the file [schema.sql](file:///c:/Users/RU/Documents/pop/SPOTon/schema.sql) in this repository, copy all its contents, paste it into the SQL Editor, and click **Run**.
4. This will automatically generate:
   - Tables: `profiles`, `conversations`, `messages`, `blocks`, `username_change_history`
   - Indexes for fast username lookups and message streams
   - The PostgreSQL trigger `trg_enforce_message_limit` enforcing the 3-message rule
   - Row Level Security (RLS) policies protecting user data

### Step 3: Configure Supabase Storage (`avatars`)
The `schema.sql` script creates the `avatars` bucket automatically. Verify in the Supabase Dashboard:
1. Go to **Storage > Buckets**.
2. Ensure the bucket `avatars` is present and marked **Public**.

### Step 4: Add Your Credentials to `js/config.js`
1. In the Supabase Dashboard, navigate to **Project Settings > API**.
2. Copy your **Project URL** and **anon (public)** key.
3. Open [js/config.js](file:///c:/Users/RU/Documents/pop/SPOTon/js/config.js) and update the `SUPABASE` section:
   ```javascript
   SUPABASE: {
     USE_LIVE_SUPABASE: true,
     URL: "https://your-project-id.supabase.co",
     ANON_KEY: "your-actual-anon-key",
     STORAGE_BUCKET: "avatars"
   }
   ```
4. Save the file and refresh `index.html` in your browser. You are now running on live Supabase!

---

## 🧪 Step-by-Step Feature Testing Guide

### 1. Registration & Math CAPTCHA
1. On the Landing Page, click **Create Free Account**.
2. Enter username (3–20 alphanumeric chars), password (min 6 chars), and repeat password.
3. Solve the arithmetic CAPTCHA equation (e.g. `7 + 4 = 11`).
4. Click **Complete Registration**. The app creates the user via Supabase Auth and inserts their profile record into `public.profiles`.

### 2. User Search (`@username`)
1. Click the **🔍 Search** button in the top right of the sidebar.
2. Search for `@siti` or `@alvis`.
3. The result card displays their avatar, display name, bio, current status, and online status (`Online` vs `Last seen Xm ago`).
4. Click **Message** to start a conversation.

### 3. Unknown Users & The 3-Message Gate (Section 11 & 12)
1. Register a new user (e.g. `@newbie`).
2. Search for `@budi` and click **Message**.
3. Notice that `@newbie` is unknown to `@budi`. The conversation is created in state `pending_request`.
4. Send **Message 1**: ✅ Allowed (`1/3 sent`).
5. Send **Message 2**: ✅ Allowed (`2/3 sent`).
6. Send **Message 3**: ✅ Allowed (`3/3 sent`).
7. Send **Message 4**: 🛑 **Blocked by the backend trigger!** An alert notifies: *"Message limit reached (3/3). Waiting for recipient to approve the conversation."*
8. Log out and log into `@budi` (`password123`).
9. Notice the **📩 Message Requests (1)** notification banner in the sidebar.
10. Click it to view the request and select **Accept**.
11. The restriction is lifted! Unlimited messaging is now unlocked.

### 4. Message Replies & Read Receipts (Section 14 & 15)
1. Hover or tap on any message bubble and click the **Reply (↩)** icon.
2. Notice the quote preview banner above the composer: *"Replying to Siti: 'iya wkwkwk'"*.
3. Type your response and hit **Send**. The reply renders with a clean quote box referencing the original message.
4. Check the delivery marks on sent messages:
   - `✓` Sent
   - `✓✓` Delivered
   - `✓✓` (colored) Read when opened by the recipient.

### 5. BBM-Style Personal Status Updates (Section 17)
1. Click the **Status** tab in the navigation bar.
2. Type a personal status update (e.g. `"lagi belajar Supabase 🚀🔥"`), select an emoji shortcut, and click **Update**.
3. The status is saved to your record in `public.profiles` and instantly appears in the feed with your avatar and relative timestamp ("Just now", "10m ago").

### 6. Username Change Quotas & 3-Day Cooldown (Section 10)
1. Navigate to the **Me** tab in the navigation bar.
2. Scroll down to **Username Changes**.
3. For new users, notice the badge: `Username changes remaining: 3`.
4. Change your username. The counter updates to `2`.
5. For `@budi` (who has already used all 3 changes), notice the badge:
   `You can change your username again in 2 days.`
6. Attempting to change username while on cooldown is rejected by backend rules.

### 7. Profile Picture Upload via Supabase Storage (Section 8 & 9)
1. In the **Me** tab, click the avatar or **Change Picture**.
2. Select any JPG, PNG, or WebP image under 2MB.
3. The image is uploaded to the Supabase Storage bucket `avatars`, the public URL is retrieved, and the user's `avatar_url` in `public.profiles` is updated.

### 8. Privacy Settings & Account Blocking (Section 11 & 18)
1. In the **Me** tab, check **Privacy Controls**:
   - Change **Who can find me?** to `Nobody`. When another user searches for your username, your profile is excluded from search results.
   - Toggle **Allow message requests** off. Unknown users will be barred from sending requests.
2. In any chat header or search result, click **Block**. The blocked user is moved to **Blocked Accounts** in the **Me** tab, and can be unblocked anytime with the **Unblock** button.

---

## 🗄️ Supabase PostgreSQL Database Design

### 1. `profiles`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Primary Key, references `auth.users(id)` on delete cascade |
| `username` | `text` | Unique username (e.g. `alvis`) |
| `username_lower` | `text` | Indexed lowercase username for case-insensitive search |
| `display_name` | `text` | Display name |
| `avatar_url` | `text` | URL to image in Supabase Storage |
| `bio` | `text` | Short biography |
| `current_status` | `text` | BBM-style personal status |
| `status_updated_at`| `timestamptz` | When status was last updated |
| `who_can_find_me` | `text` | `'everyone'` or `'nobody'` |
| `allow_message_requests` | `boolean` | Whether unknown users can send requests |
| `username_changes_count` | `int` | Number of changes used in current cycle |
| `last_username_change` | `timestamptz` | Timestamp of last username change |
| `last_seen` | `timestamptz` | Last heartbeat/activity timestamp |
| `created_at` | `timestamptz` | Creation timestamp |

### 2. `conversations`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Primary Key |
| `participant_one` | `uuid` | References `profiles(id)` |
| `participant_two` | `uuid` | References `profiles(id)` |
| `status` | `text` | `'active'`, `'pending_request'`, or `'declined'` |
| `request_initiator_id` | `uuid` | Who started the conversation |
| `request_recipient_id` | `uuid` | Who must approve the conversation |
| `unknown_message_count`| `int` | Counter tracking the 3-message limit (0..3) |
| `last_message_content` | `text` | Snippet for conversation preview |
| `last_message_sender_id`| `uuid` | Who sent the last message |
| `last_message_timestamp`| `timestamptz`| Timestamp of the last message |

### 3. `messages`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Primary Key |
| `conversation_id` | `uuid` | References `conversations(id)` |
| `sender_id` | `uuid` | References `profiles(id)` |
| `content` | `text` | Message body text |
| `reply_to_message_id` | `uuid` | Nullable reference to original message |
| `reply_to_sender_name`| `text` | Cached sender name of replied message |
| `reply_to_snippet` | `text` | Cached snippet of replied message |
| `status` | `text` | `'sent'`, `'delivered'`, or `'read'` |
| `created_at` | `timestamptz` | When sent |
| `read_at` | `timestamptz` | When read by recipient |

### 4. `blocks`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Primary Key |
| `blocker_id` | `uuid` | User who initiated the block |
| `blocked_id` | `uuid` | User who is blocked |
| `created_at` | `timestamptz` | Block timestamp |

### 5. `username_change_history`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Primary Key |
| `user_id` | `uuid` | References `profiles(id)` |
| `old_username` | `text` | Previous username |
| `new_username` | `text` | New username |
| `changed_at` | `timestamptz` | When change occurred |

---

## 🔒 Security & Row Level Security (RLS)

1. **Supabase Auth**: Passwords are securely stored in Supabase's managed `auth.users` table using bcrypt.
2. **Row Level Security (RLS)**:
   - `profiles`: Readable according to `who_can_find_me` and blocking rules; updatable only by the owner (`auth.uid() = id`).
   - `conversations`: Only participants (`participant_one = auth.uid()` or `participant_two = auth.uid()`) can view or insert.
   - `messages`: Only conversation participants can view or send messages.
   - `blocks`: Only the blocker can view or insert their blocks.
3. **Database Trigger**: The 3-message limit is enforced at the database level by the `enforce_unknown_user_message_limit()` PostgreSQL function, preventing any client-side bypass.

---

## 🌐 Migration to Vercel / Cloud Hosting

When deploying SPOTon Chat to **Vercel** or another cloud host:

1. In your hosting dashboard (e.g. Vercel Project Settings > Environment Variables), define:
   - `SUPABASE_URL`: Your Supabase Project URL
   - `SUPABASE_ANON_KEY`: Your Supabase Public Anon Key
   - `SUPABASE_STORAGE_BUCKET`: `avatars`
2. **Public vs Private Keys**:
   - The `ANON_KEY` is **safe** for client-side use because data access is protected by Row Level Security (RLS).
   - The `SERVICE_ROLE_KEY` is **private** and must NEVER be exposed in frontend code.
