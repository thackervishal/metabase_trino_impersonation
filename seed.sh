#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"
set +a

API="http://127.0.0.1:${METABASE_PORT}"
KEY="$MB_AUTOMATION_API_KEY"

api() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" "$API$path" -H "Content-Type: application/json" -H "x-api-key: $KEY" -d "$data"
  else
    curl -fsS -X "$method" "$API$path" -H "x-api-key: $KEY"
  fi
}

echo "Waiting for Metabase..."
until curl -fsS "$API/api/health" >/dev/null 2>&1; do sleep 3; done

echo "Waiting for the automation API key to become active..."
until curl -fsS "$API/api/user/current" -H "x-api-key: $KEY" >/dev/null 2>&1; do sleep 3; done

echo "Looking up the trino_test database id..."
DB_ID="$(api GET /api/database | jq -r '.data[] | select(.name == "trino_test") | .id')"
echo "  db_id=$DB_ID"

echo "Creating groups..."
SALES_GROUP_ID="$(api POST /api/permissions/group '{"name": "Sales Team"}' | jq -r '.id')"
ANALYTICS_GROUP_ID="$(api POST /api/permissions/group '{"name": "Analytics Team"}' | jq -r '.id')"
echo "  Sales Team id=$SALES_GROUP_ID"
echo "  Analytics Team id=$ANALYTICS_GROUP_ID"

create_user() {
  local email="$1" first="$2" last="$3" group_id="$4" trino_user="${5:-}"
  local attrs='null'
  if [[ -n "$trino_user" ]]; then
    attrs="$(jq -n --arg u "$trino_user" '{trino_user: $u}')"
  fi
  api POST /api/user "$(jq -n \
    --arg email "$email" --arg first "$first" --arg last "$last" \
    --arg pw "$USER_PASSWORD" --argjson attrs "$attrs" --argjson gid "$group_id" \
    '{
      first_name: $first, last_name: $last, email: $email, password: $pw,
      login_attributes: $attrs,
      user_group_memberships: [{id: 1}, {id: $gid}]
    }')" | jq -r '.email'
}

echo "Creating Sales Team users (Leo, Mikey)..."
create_user "$LEO_EMAIL" "Leo" "Sales" "$SALES_GROUP_ID" "leo"
create_user "$MIKEY_EMAIL" "Mikey" "Sales" "$SALES_GROUP_ID" "mikey"

echo "Creating Analytics Team users (Ralph, Donny — no user attribute)..."
create_user "$RALPH_EMAIL" "Ralph" "Analytics" "$ANALYTICS_GROUP_ID"
create_user "$DONNY_EMAIL" "Donny" "Analytics" "$ANALYTICS_GROUP_ID"

echo "Setting data permissions for trino_test..."
GRAPH="$(api GET /api/permissions/graph)"
UPDATED_GRAPH="$(echo "$GRAPH" | jq \
  --arg db "$DB_ID" --arg sales "$SALES_GROUP_ID" --arg analytics "$ANALYTICS_GROUP_ID" \
  '
  .groups["1"] = ((.groups["1"] // {}) + {($db): {"view-data": "blocked", "create-queries": "no"}})
  | .groups[$sales] = ((.groups[$sales] // {}) + {($db): {"view-data": "impersonated", "create-queries": "query-builder-and-native"}})
  | .groups[$analytics] = ((.groups[$analytics] // {}) + {($db): {"view-data": "unrestricted", "create-queries": "query-builder-and-native"}})
  | .impersonations = [{"db_id": ($db | tonumber), "group_id": ($sales | tonumber), "attribute": "trino_user"}]
  ')"
api PUT /api/permissions/graph "$UPDATED_GRAPH" >/dev/null

echo
echo "------------------------------------------------------------"
echo "  Seed complete"
echo "------------------------------------------------------------"
echo "  Metabase        http://localhost:${METABASE_PORT}"
echo "    admin         ${ADMIN_EMAIL}  /  ${USER_PASSWORD}"
echo "    leo (sales)   ${LEO_EMAIL}  /  ${USER_PASSWORD}"
echo "    mikey (sales) ${MIKEY_EMAIL}  /  ${USER_PASSWORD}"
echo "    ralph (analytics, unrestricted, no impersonation) ${RALPH_EMAIL}  /  ${USER_PASSWORD}"
echo "    donny (analytics, unrestricted, no impersonation) ${DONNY_EMAIL}  /  ${USER_PASSWORD}"
echo "------------------------------------------------------------"
