import { test, expect } from "@playwright/test";

// ---------------------------------------------------------------------------
// 1. Dashboard Page Load
// ---------------------------------------------------------------------------
test.describe("Dashboard page load", () => {
  test("renders title, nav, search form, and footer", async ({ page }) => {
    await page.goto("/");

    // Title
    await expect(page).toHaveTitle("DOL Cases Dashboard");

    // Nav links
    const nav = page.locator("nav");
    await expect(nav.getByRole("link", { name: "Dashboard", exact: true })).toBeVisible();
    await expect(
      nav.getByRole("link", { name: "Import Data" })
    ).toBeVisible();

    // Search section
    await expect(page.locator("h2", { hasText: "Search Cases" })).toBeVisible();

    // Form fields
    await expect(page.locator("#program-select")).toBeVisible();
    await expect(page.locator('input[name="year"]')).toBeVisible();
    await expect(page.locator('select[name="quarter"]')).toBeVisible();
    await expect(page.locator('input[name="employer"]')).toBeVisible();
    await expect(page.locator('input[name="job_title"]')).toBeVisible();
    await expect(page.locator('input[name="state"]')).toBeVisible();
    await expect(page.locator('select[name="status"]')).toBeVisible();
    await expect(page.locator('input[name="visa_class"]')).toBeVisible();
    await expect(page.locator('input[name="case_number"]')).toBeVisible();

    // Footer with DOL link
    const footer = page.locator("footer");
    await expect(footer.getByRole("link", { name: /DOL/i })).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 2. Import Page
// ---------------------------------------------------------------------------
test.describe("Import page", () => {
  test("renders import form with expected fields", async ({ page }) => {
    await page.goto("/import");

    await expect(
      page.locator("h2", { hasText: "Import Data" })
    ).toBeVisible();

    // Program, Year, Quarter fields
    await expect(page.locator('select[name="program"]')).toBeVisible();
    await expect(page.locator('input[name="year"]')).toBeVisible();
    await expect(page.locator('select[name="quarter"]')).toBeVisible();

    // Force re-download checkbox
    await expect(page.locator('input[name="refresh"]')).toBeVisible();

    // Submit button
    await expect(
      page.getByRole("button", { name: "Start Import" })
    ).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 3. Search - No Data (PERM not imported)
// ---------------------------------------------------------------------------
test.describe("Search - no data", () => {
  test("shows error when searching unimported program", async ({ page }) => {
    await page.goto("/");

    await page.locator("#program-select").selectOption("perm");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.getByRole("button", { name: "Search" }).click();

    // Wait for htmx response
    const resultsArea = page.locator("#results-area");
    await expect(
      resultsArea.locator('article[aria-label="error"]')
    ).toBeVisible({ timeout: 10_000 });
    await expect(resultsArea).toContainText("No data imported");
    await expect(
      resultsArea.getByRole("link", { name: /Import/i })
    ).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 4. Search - With Results (LCA seeded data)
// ---------------------------------------------------------------------------
test.describe("Search - with results", () => {
  test("shows stats cards and results table", async ({ page }) => {
    await page.goto("/");

    await page.locator("#program-select").selectOption("lca");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.getByRole("button", { name: "Search" }).click();

    const resultsArea = page.locator("#results-area");

    // Stats cards
    await expect(resultsArea.locator("#stats-area")).toBeVisible({
      timeout: 10_000,
    });
    await expect(resultsArea).toContainText("Total Cases");
    await expect(resultsArea).toContainText("Median Wage");
    await expect(resultsArea).toContainText("Min Wage");
    await expect(resultsArea).toContainText("Max Wage");

    // Results table headers
    const table = resultsArea.locator("table[role='grid']");
    await expect(table).toBeVisible();
    const headers = table.locator("thead th");
    await expect(headers).toContainText([
      "Case Number",
      "Status",
      "Employer",
      "Job Title",
      "City",
      "State",
      "Wage",
      "Visa Class",
    ]);

    // At least 1 row
    const rows = table.locator("tbody tr");
    await expect(rows.first()).toBeVisible();
    expect(await rows.count()).toBeGreaterThanOrEqual(1);
  });
});

// ---------------------------------------------------------------------------
// 5. Search - Filter by Employer
// ---------------------------------------------------------------------------
test.describe("Search - filter by employer", () => {
  test("filters results to matching employer", async ({ page }) => {
    await page.goto("/");

    await page.locator("#program-select").selectOption("lca");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.locator('input[name="employer"]').fill("GOOGLE");
    await page.getByRole("button", { name: "Search" }).click();

    const resultsArea = page.locator("#results-area");
    const table = resultsArea.locator("table[role='grid']");
    await expect(table).toBeVisible({ timeout: 10_000 });

    // All employer cells should contain GOOGLE
    const employerCells = table.locator("tbody tr td:nth-child(3)");
    const count = await employerCells.count();
    expect(count).toBeGreaterThanOrEqual(1);
    for (let i = 0; i < count; i++) {
      await expect(employerCells.nth(i)).toContainText(/GOOGLE/i);
    }

    // Results count shown
    await expect(resultsArea.locator("h3")).toContainText(/total/i);
  });
});

// ---------------------------------------------------------------------------
// 6. Search - No Results
// ---------------------------------------------------------------------------
test.describe("Search - no results", () => {
  test("shows no results message for nonexistent employer", async ({
    page,
  }) => {
    await page.goto("/");

    await page.locator("#program-select").selectOption("lca");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.locator('input[name="employer"]').fill("ZZZZNONEXISTENT");
    await page.getByRole("button", { name: "Search" }).click();

    const resultsArea = page.locator("#results-area");
    await expect(resultsArea).toContainText("No results found", {
      timeout: 10_000,
    });
  });
});

// ---------------------------------------------------------------------------
// 7. Search - htmx Partial Update
// ---------------------------------------------------------------------------
test.describe("Search - htmx partial update", () => {
  test("updates results without full page reload", async ({ page }) => {
    await page.goto("/");

    // First search
    await page.locator("#program-select").selectOption("lca");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.getByRole("button", { name: "Search" }).click();

    const resultsArea = page.locator("#results-area");
    await expect(
      resultsArea.locator("table[role='grid']")
    ).toBeVisible({ timeout: 10_000 });

    // Mark the nav to detect full reload
    await page.evaluate(() => {
      document.querySelector("nav")!.setAttribute("data-e2e-marker", "alive");
    });

    // Second search with employer filter
    await page.locator('input[name="employer"]').fill("APPLE");
    await page.getByRole("button", { name: "Search" }).click();

    // Wait for results to update
    await expect(resultsArea).toContainText("APPLE", { timeout: 10_000 });

    // Nav marker should still exist (no full reload)
    const marker = await page
      .locator("nav")
      .getAttribute("data-e2e-marker");
    expect(marker).toBe("alive");
  });
});

// ---------------------------------------------------------------------------
// 8. Chart.js Rendering
// ---------------------------------------------------------------------------
test.describe("Chart.js rendering", () => {
  test("renders wage and status chart canvases", async ({ page }) => {
    await page.goto("/");

    await page.locator("#program-select").selectOption("lca");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.getByRole("button", { name: "Search" }).click();

    // Wait for charts to appear
    const wageChart = page.locator("#wage-chart");
    const statusChart = page.locator("#status-chart");

    await expect(wageChart).toBeVisible({ timeout: 10_000 });
    await expect(statusChart).toBeVisible();

    // Verify canvases have non-zero dimensions (Chart.js rendered)
    const wageBox = await wageChart.boundingBox();
    expect(wageBox).not.toBeNull();
    expect(wageBox!.width).toBeGreaterThan(0);
    expect(wageBox!.height).toBeGreaterThan(0);

    const statusBox = await statusChart.boundingBox();
    expect(statusBox).not.toBeNull();
    expect(statusBox!.width).toBeGreaterThan(0);
    expect(statusBox!.height).toBeGreaterThan(0);
  });
});

// ---------------------------------------------------------------------------
// 9. Pagination
// ---------------------------------------------------------------------------
test.describe("Pagination", () => {
  test("does not show pagination for small result sets", async ({ page }) => {
    // Our fixture only has 10 rows, per_page is 50, so no pagination
    await page.goto("/");

    await page.locator("#program-select").selectOption("lca");
    await page.locator('input[name="year"]').fill("2024");
    await page.locator('select[name="quarter"]').selectOption("3");
    await page.getByRole("button", { name: "Search" }).click();

    const resultsArea = page.locator("#results-area");
    await expect(
      resultsArea.locator("table[role='grid']")
    ).toBeVisible({ timeout: 10_000 });

    // With only 10 rows and per_page=50, pagination nav should not appear
    await expect(
      resultsArea.locator('nav[aria-label="Pagination"]')
    ).toHaveCount(0);
  });
});

// ---------------------------------------------------------------------------
// 10. Security Headers
// ---------------------------------------------------------------------------
test.describe("Security headers", () => {
  test("returns expected security headers", async ({ request }) => {
    const response = await request.get("/");
    const headers = response.headers();

    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["x-frame-options"]).toBe("DENY");
    expect(headers["referrer-policy"]).toBe(
      "strict-origin-when-cross-origin"
    );
  });
});

// ---------------------------------------------------------------------------
// 11. 404 Page
// ---------------------------------------------------------------------------
test.describe("404 page", () => {
  test("shows error for unknown routes", async ({ page }) => {
    const response = await page.goto("/nonexistent");
    expect(response?.status()).toBe(404);
    await expect(page.locator("body")).toContainText("Page not found");
  });
});

// ---------------------------------------------------------------------------
// 12. CSRF Meta Tag
// ---------------------------------------------------------------------------
test.describe("CSRF meta tag", () => {
  test("includes csrf-token meta tag with non-empty content", async ({
    page,
  }) => {
    await page.goto("/");
    const csrfMeta = page.locator('meta[name="csrf-token"]');
    await expect(csrfMeta).toHaveCount(1);
    const content = await csrfMeta.getAttribute("content");
    expect(content).toBeTruthy();
    expect(content!.length).toBeGreaterThan(0);
  });
});
