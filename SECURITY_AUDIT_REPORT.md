# Cal.com Security Audit Report - External Communications

**Date:** October 4, 2025
**Audited By:** Claude Code
**Repository:** 23blocks/scheduler (Cal.com self-hosted)
**Version:** v0.0.5

---

## Executive Summary

This audit identifies all external communications from the Cal.com application to cal.com-owned services and third-party domains. For secure environments, these communications can be **completely disabled** through environment variables.

**Key Finding:** ✅ **The application CAN be made air-tight** by properly configuring environment variables.

---

## External Communications Found

### 1. **Telemetry System** ⚠️ ACTIVE BY DEFAULT

**Service:** Jitsu Analytics
**Domain:** `https://t.calendso.com`
**Location:** `packages/lib/telemetry.ts:66`

**What it sends:**
- Page views
- API calls
- Booking events (confirmed, cancelled)
- Login events
- Signup events
- Team/org creation events
- License key information

**Data collected:**
- Page URLs
- License key (if set)
- Team/org status
- Authentication status
- Timestamp
- Vercel deployment status

**How to DISABLE:**
```bash
CALCOM_TELEMETRY_DISABLED=1
```

---

### 2. **License Validation** ⚠️ ACTIVE IF LICENSE KEY SET

**Service:** Cal.com Private API (Goblin)
**Domain:** `https://goblin.cal.com`
**Location:** `packages/features/ee/common/server/LicenseKeyService.ts`

**What it sends:**
- License key
- Usage events (bookings, users)
- Nonce and signature for validation

**Endpoints called:**
- `GET /v1/license/{LICENSE_KEY}` - Validates license every 24 hours
- `POST /v1/license/usage/increment` - Reports usage metrics

**How to DISABLE:**
```bash
# Simply don't set these variables:
# CALCOM_LICENSE_KEY=
# CAL_SIGNATURE_TOKEN=
```

**Note:** Without these, the app uses `NoopLicenseKeyService` which does nothing.

---

### 3. **Console Usage Reporting** ⚠️ ACTIVE IF LICENSE KEY SET

**Service:** Cal.com Console
**Domain:** `https://console.cal.com` (production) or `https://console.cal.dev` (non-prod)
**Location:** `packages/lib/telemetry.ts:45`

**What it sends:**
- Booking confirmation events
- License key
- Usage quantity

**When it sends:**
- Every booking confirmation
- Every embed booking confirmation

**How to DISABLE:**
```bash
# Don't set:
# CALCOM_LICENSE_KEY=
```

---

### 4. **Hardcoded External URLs** ℹ️ INFORMATIONAL ONLY

These are **UI links only** (no data sent):

**Cal.com Links:**
- Documentation: `https://cal.com/docs`
- Developer docs: `https://developer.cal.com`
- Roadmap: `https://cal.com/roadmap`
- Downloads: `https://cal.com/download`
- Powered by: `https://go.cal.com/booking`
- Community: `https://github.com/calcom/cal.com/discussions`
- Privacy policy: `https://cal.com/privacy`
- Terms: `https://cal.com/terms`
- Support: `https://go.cal.com/support`

**These can be customized:**
```bash
NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL="https://23blocks.com/privacy"
NEXT_PUBLIC_WEBSITE_TERMS_URL="https://23blocks.com/terms"
```

---

## Third-Party Services (Optional Integrations)

These are **ONLY active if YOU configure them**:

### Analytics & Monitoring (All Optional)
- **PostHog:** `NEXT_PUBLIC_POSTHOG_KEY` (not set = disabled)
- **Sentry:** `NEXT_PUBLIC_SENTRY_DSN` (not set = disabled)
- **Intercom:** `NEXT_PUBLIC_INTERCOM_APP_ID` (not set = disabled)
- **Formbricks:** `NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID` (not set = disabled)

### Communication Services (All Optional)
- **Sendgrid:** Only if you configure `SENDGRID_API_KEY`
- **Twilio:** Only if you configure `TWILIO_SID`
- **SMTP:** Only if you configure email server credentials

---

## Recommended Secure Configuration

For a **completely air-tight installation**, use this `.env` configuration:

```bash
# ============================================
# CORE REQUIREMENTS (MUST SET)
# ============================================
DATABASE_URL="postgresql://..."
NEXTAUTH_SECRET="your-secret-here"
CALENDSO_ENCRYPTION_KEY="your-encryption-key-here"
NEXT_PUBLIC_WEBAPP_URL="https://your-domain.com"

# ============================================
# DISABLE ALL EXTERNAL COMMUNICATIONS
# ============================================
CALCOM_TELEMETRY_DISABLED=1
# Do NOT set CALCOM_LICENSE_KEY
# Do NOT set CAL_SIGNATURE_TOKEN
# Do NOT set CALCOM_PRIVATE_API_ROUTE

# ============================================
# DISABLE OPTIONAL ANALYTICS
# ============================================
# Do NOT set NEXT_PUBLIC_POSTHOG_KEY
# Do NOT set NEXT_PUBLIC_SENTRY_DSN
# Do NOT set NEXT_PUBLIC_INTERCOM_APP_ID
# Do NOT set NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID

# ============================================
# CUSTOM BRANDING (Optional)
# ============================================
NEXT_PUBLIC_APP_NAME="23blocks Scheduler"
NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL="https://23blocks.com/privacy"
NEXT_PUBLIC_WEBSITE_TERMS_URL="https://23blocks.com/terms"
```

---

## Verification Steps

To verify no external communications are happening:

### 1. Check Environment Variables
```bash
# SSH into your server
printenv | grep -E "CALCOM_TELEMETRY|CALCOM_LICENSE|POSTHOG|SENTRY|INTERCOM"
```

Should return:
```
CALCOM_TELEMETRY_DISABLED=1
```

### 2. Monitor Network Traffic
```bash
# Install tcpdump or use your network monitoring tool
tcpdump -i any -n 'host cal.com or host calendso.com or host goblin.cal.com'
```

Should show **NO traffic** to these domains when:
- Users browse the app
- Bookings are created
- Users sign up/login

### 3. Check Application Logs
```bash
docker logs scheduler-container 2>&1 | grep -E "cal\.com|calendso\.com|telemetry|license"
```

Should show no outbound requests (except in error messages if license is configured).

---

## Security Recommendations

### ✅ HIGH Priority (Do These Now)

1. **Set `CALCOM_TELEMETRY_DISABLED=1`** in your production environment
2. **Do NOT set `CALCOM_LICENSE_KEY`** or `CAL_SIGNATURE_TOKEN`
3. **Review all environment variables** to ensure no analytics services are configured
4. **Use private email server** (Mandrill via SMTP) instead of Sendgrid API

### ✅ MEDIUM Priority

5. **Custom branding URLs** to remove cal.com links from UI
6. **Network firewall rules** to block outbound traffic to:
   - `*.cal.com`
   - `*.calendso.com`
   - `t.calendso.com` (telemetry)
   - `goblin.cal.com` (license API)

### ✅ LOW Priority (Nice to Have)

7. **Code audit** - Remove unused telemetry code in a fork
8. **Monitoring** - Set up alerts for any unexpected outbound connections
9. **Regular reviews** - Check for new external services after upgrades

---

## Current Deployment Status

**Your v0.0.5 deployment:**
- ✅ Telemetry: Should be disabled (verify `CALCOM_TELEMETRY_DISABLED=1`)
- ✅ License validation: Not configured (no license key)
- ✅ Usage reporting: Not configured (no license key)
- ℹ️  Third-party services: Only if you configure them

**Action Required:**
1. Verify `CALCOM_TELEMETRY_DISABLED=1` is set in your environment
2. Confirm no license keys are configured
3. Check no analytics services are configured

---

## License Considerations

**Important:** This is the open-source version under AGPLv3. You have:
- ✅ Full rights to use, modify, and deploy
- ✅ No requirement to use Cal.com services
- ✅ No requirement for license keys
- ⚠️  Must keep source code open (AGPLv3 requirement)
- ⚠️  Cannot use "Cal.com" trademark without permission

**Enterprise features** we removed license checks from:
- API Keys management
- SSO configuration
- Workflows
- Organizations
- Teams management
- All other "enterprise" features

These work fine without any license keys.

---

## Conclusion

**Is the software air-tight?**

✅ **YES** - When properly configured with `CALCOM_TELEMETRY_DISABLED=1` and no license keys.

**What needs to be done:**

1. Set `CALCOM_TELEMETRY_DISABLED=1` in environment
2. Verify no license keys are configured
3. Optional: Add firewall rules to block cal.com domains
4. Optional: Monitor network traffic to verify

**All external communications can be completely disabled through configuration.**

---

## Questions or Concerns?

If you need to verify any specific behavior or want to audit additional code paths, let me know and I can investigate further.

---

**Audit completed:** October 4, 2025
**Next review:** After major version upgrades
