# frozen_string_literal: true

# Pagy pagination defaults. See https://ddnexus.github.io/pagy/
require "pagy"

# Default number of items per page (overridable per-request via ?items=).
Pagy::DEFAULT[:items] = 25
Pagy::DEFAULT[:max_items] = 100

# Return pagination info even when the collection fits on a single page.
Pagy::DEFAULT[:overflow] = :last_page
