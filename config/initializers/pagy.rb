# frozen_string_literal: true

# Pagy pagination defaults. See https://ddnexus.github.io/pagy/
require "pagy"

# Default page size (overridable per-request via ?limit=).
Pagy::DEFAULT[:limit] = 25
Pagy::DEFAULT[:max_limit] = 100

# Clamp out-of-range pages to the last page instead of raising.
Pagy::DEFAULT[:overflow] = :last_page
