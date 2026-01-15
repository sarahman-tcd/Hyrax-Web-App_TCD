// AJAX Pagination for Date-Filtered Search
// This handles pagination for searches with date range filters

console.log('ajax_pagination.js loaded');

function initAjaxPagination() {
  console.log('initAjaxPagination called');

  // Inject custom styles
  injectStyles();

  // Wait a bit for DOM to be fully ready
  setTimeout(function () {
    console.log('Timeout fired, checking for date filter');

    // Check if we have a date filter in the URL
    const urlParams = new URLSearchParams(window.location.search);
    const query = urlParams.get('q');
    console.log('Query parameter:', query);

    if (query && query.includes('date_created_tesim')) {
      console.log('Date filter detected, using AJAX pagination');

      // Extract date range
      const match = query.match(/date_created_tesim:\[(-?\d+)TO(-?\d+)\]/);

      if (match) {
        const startYear = match[1];
        const endYear = match[2];
        const cleanQuery = query.replace(/AND?\s*\(?date_created_tesim:\[.*?\]\)?/, '').trim();

        // Hide ALL Blacklight pagination elements
        console.log('Hiding Blacklight elements...');

        // Use attr('style') to absolutely override any CSS
        // Only hide specific result-related elements, not search inputs
        $('.pagination').attr('style', 'display: none !important;');
        $('.page-entries').attr('style', 'display: none !important;');
        $('.pagination-search-widgets').attr('style', 'display: none !important;');
        $('#sortAndPerPage').attr('style', 'display: none !important;');
        $('.sort-pagination').attr('style', 'display: none !important;');

        // Hide the main search results container (this is the key one!)
        $('#search-results').attr('style', 'display: none !important;');
        $('.search-results').attr('style', 'display: none !important;');

        // Hide document list if it exists
        $('#documents').attr('style', 'display: none !important;');
        $('.documents-list').attr('style', 'display: none !important;');

        // Log what was found
        console.log('Documents found:', $('#documents').length);
        console.log('Pagination found:', $('.pagination').length);
        console.log('Search results found:', $('#search-results').length);

        console.log('Blacklight elements hidden');

        // Show AJAX container
        $('#ajax-results').show();
        $('#ajax-results').attr('style', 'display: block !important;');
        console.log('AJAX container shown');

        // Get initial params
        const page = urlParams.get('page') || 1;
        const perPage = urlParams.get('per_page') || 10;
        const sort = urlParams.get('sort') || 'score desc, system_create_dtsi desc';

        console.log('Loading page:', page);
        loadFilteredResults(cleanQuery, startYear, endYear, parseInt(page), parseInt(perPage), sort);
      }
    }
  }, 200);
}

// Run on initial load and Turbolinks load
$(document).ready(function () {
  initAjaxPagination();
});

$(document).on('turbolinks:load', function () {
  initAjaxPagination();
});

function loadFilteredResults(query, startYear, endYear, page, perPage, sort) {
  console.log(`Loading page ${page}, per_page ${perPage}, sort ${sort}`);

  // Show loading indicator with overlay
  $('#ajax-documents').html(`
    <div class="ajax-loading-overlay">
      <div class="ajax-loading-spinner"></div>
      <div class="ajax-loading-text">Loading results...</div>
    </div>
  `);

  $.ajax({
    url: '/catalog/filtered_search',
    data: {
      q: query,
      start_year: startYear,
      end_year: endYear,
      page: page,
      per_page: perPage,
      sort: sort
    },
    success: function (data) {
      renderControls(data.pagination, query, startYear, endYear, sort, perPage);
      renderResults(data.documents);
      renderPagination(data.pagination, query, startYear, endYear, sort, perPage);
    },
    error: function (xhr, status, error) {
      console.error('AJAX error:', error);
      $('#ajax-documents').html(`<div class="error">Error loading results: ${error}</div>`);
    }
  });
}

// Inject Custom Styles
function injectStyles() {
  if ($('#ajax-pagination-styles').length > 0) return;

  const styles = `
    <style id="ajax-pagination-styles">
      .ajax-result-card {
        background: #fff;
        border: 1px solid #e1e4e8;
        border-radius: 6px;
        padding: 20px;
        margin-bottom: 16px;
        transition: all 0.2s ease-in-out;
        display: flex;
        align-items: flex-start;
      }
      .ajax-result-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(149, 157, 165, 0.2);
        border-color: #d1d5da;
      }
      .ajax-thumbnail-container {
        flex: 0 0 100px;
        margin-right: 20px;
      }
      .ajax-thumbnail {
        width: 100%;
        height: auto;
        border-radius: 4px;
        border: 1px solid #eaecef;
        display: block;
      }
      .ajax-content {
        flex: 1;
        min-width: 0; /* Fix for flexbox truncation */
      }
      .ajax-title {
        margin: 0 0 8px 0;
        font-size: 18px;
        font-weight: 600;
        line-height: 1.4;
      }
      .ajax-title a {
        color: #1074b7;
        text-decoration: none;
      }
      .ajax-title a:hover {
        text-decoration: underline;
      }
      .ajax-meta-row {
        display: flex;
        margin-bottom: 4px;
        font-size: 14px;
        line-height: 1.5;
      }
      .ajax-label {
        flex: 0 0 120px;
        font-weight: 600;
        color: #586069;
      }
      .ajax-value {
        flex: 1;
        color: #24292e;
      }
      .ajax-controls-container {
        background: #f6f8fa;
        border: 1px solid #e1e4e8;
        border-radius: 6px;
        padding: 12px 20px;
        margin-bottom: 24px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        flex-wrap: wrap;
      }
      .ajax-controls-info {
        font-weight: 600;
        color: #24292e;
      }
      .ajax-controls-actions {
        display: flex;
        gap: 15px;
        align-items: center;
      }
      .ajax-select-wrapper {
        position: relative;
      }
      .ajax-select-wrapper select {
        border-radius: 4px;
        border: 1px solid #d1d5da;
        padding: 4px 8px;
        background-color: #fff;
        font-size: 13px;
        height: 32px;
      }
      .truncate-3-lines {
        display: -webkit-box;
        -webkit-line-clamp: 3;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }
      /* Loading State */
      .ajax-loading-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(255, 255, 255, 0.9);
        z-index: 10000;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
      }
      .ajax-loading-spinner {
        width: 50px;
        height: 50px;
        border: 4px solid #e1e4e8;
        border-top-color: #1074b7;
        border-radius: 50%;
        animation: spin 1s linear infinite;
        margin-bottom: 15px;
      }
      .ajax-loading-text {
        color: #586069;
        font-size: 16px;
        font-weight: 500;
      }
      @keyframes spin {
        to { transform: rotate(360deg); }
      }
    </style>
  `;
  $('head').append(styles);
}

function renderControls(pagination, query, startYear, endYear, currentSort, currentPerPage) {
  const container = $('#ajax-controls-top');
  container.empty();

  const { total_count, start_index, end_index } = pagination;

  const html = `
    <div class="col-md-12">
      <div class="ajax-controls-container">
        <div class="ajax-controls-info">
          Showing ${start_index} - ${end_index} of ${total_count} results
        </div>

        <div class="ajax-controls-actions">
          <div class="ajax-select-wrapper">
            <select class="form-control input-sm ajax-sort-select">
              <option value="score desc, system_create_dtsi desc" ${currentSort.includes('score') ? 'selected' : ''}>Relevance</option>
              <option value="system_create_dtsi desc" ${currentSort === 'system_create_dtsi desc' ? 'selected' : ''}>Date Uploaded (Newest)</option>
              <option value="system_create_dtsi asc" ${currentSort === 'system_create_dtsi asc' ? 'selected' : ''}>Date Uploaded (Oldest)</option>
              <option value="system_modified_dtsi desc" ${currentSort === 'system_modified_dtsi desc' ? 'selected' : ''}>Date Modified (Newest)</option>
              <option value="system_modified_dtsi asc" ${currentSort === 'system_modified_dtsi asc' ? 'selected' : ''}>Date Modified (Oldest)</option>
            </select>
          </div>

          <div class="ajax-select-wrapper">
            <select class="form-control input-sm ajax-per-page-select">
              <option value="10" ${currentPerPage == 10 ? 'selected' : ''}>10 per page</option>
              <option value="20" ${currentPerPage == 20 ? 'selected' : ''}>20 per page</option>
              <option value="50" ${currentPerPage == 50 ? 'selected' : ''}>50 per page</option>
              <option value="100" ${currentPerPage == 100 ? 'selected' : ''}>100 per page</option>
            </select>
          </div>
        </div>
      </div>
    </div>
    <div class="col-md-12 text-center ajax-pagination-top" style="margin-top: 0;"></div>
  `;

  container.html(html);

  // Attach handlers
  $('.ajax-sort-select').change(function () {
    const newSort = $(this).val();
    updateUrlAndReload(query, startYear, endYear, 1, currentPerPage, newSort);
  });

  $('.ajax-per-page-select').change(function () {
    const newPerPage = $(this).val();
    updateUrlAndReload(query, startYear, endYear, 1, newPerPage, currentSort);
  });
}

function renderResults(documents) {
  const container = $('#ajax-documents');
  container.empty();

  if (documents.length === 0) {
    container.html('<div class="alert alert-info">No results found.</div>');
    return;
  }

  documents.forEach(doc => {
    const creators = doc.creator && doc.creator.length > 0 ? doc.creator.join(', ') : '';
    const dates = doc.date_created && doc.date_created.length > 0 ? doc.date_created.join(', ') : '';
    const resourceType = doc.resource_type && doc.resource_type.length > 0 ? doc.resource_type.join(', ') : '';

    // Thumbnail HTML
    let thumbnailHtml = '';
    if (doc.thumbnail) {
      thumbnailHtml = `
        <div class="ajax-thumbnail-container">
          <a href="${doc.url}">
            <img src="${doc.thumbnail}" class="ajax-thumbnail" alt="${doc.title}">
          </a>
        </div>
      `;
    } else {
      thumbnailHtml = `
        <div class="ajax-thumbnail-container">
          <a href="${doc.url}" style="display: block; text-align: center; background: #f6f8fa; border: 1px solid #eaecef; border-radius: 4px; height: 100px; line-height: 100px;">
            <span class="glyphicon glyphicon-file" style="font-size: 40px; color: #d1d5da; vertical-align: middle;"></span>
          </a>
        </div>
      `;
    }

    const html = `
      <div class="col-md-12">
        <div class="ajax-result-card">
          ${thumbnailHtml}

          <div class="ajax-content">
            <h3 class="ajax-title">
              <a href="${doc.url}">${doc.title}</a>
            </h3>

            <div class="ajax-metadata">
              ${creators ? `
                <div class="ajax-meta-row">
                  <span class="ajax-label">Creator:</span>
                  <span class="ajax-value truncate-3-lines" title="${creators.replace(/"/g, '&quot;')}">${creators}</span>
                </div>
              ` : ''}

              ${dates ? `
                <div class="ajax-meta-row">
                  <span class="ajax-label">Date Created:</span>
                  <span class="ajax-value truncate-3-lines" title="${dates.replace(/"/g, '&quot;')}">${dates}</span>
                </div>
              ` : ''}

              ${resourceType ? `
                <div class="ajax-meta-row">
                  <span class="ajax-label">Resource Type:</span>
                  <span class="ajax-value truncate-3-lines" title="${resourceType.replace(/"/g, '&quot;')}">${resourceType}</span>
                </div>
              ` : ''}
            </div>
          </div>
        </div>
      </div>
    `;
    container.append(html);
  });
}

function renderPagination(pagination, query, startYear, endYear, sort, perPage) {
  const bottomContainer = $('#ajax-pagination');
  const topContainer = $('.ajax-pagination-top');

  bottomContainer.empty();
  topContainer.empty();

  const { current_page, total_pages } = pagination;

  if (total_pages <= 1) return;

  let pagesHtml = '';
  const window = 2; // Show 2 pages around current

  // Previous
  pagesHtml += `
    <li class="${current_page === 1 ? 'disabled' : ''}">
      <a href="#" class="ajax-page-link" data-page="${current_page - 1}">« Previous</a>
    </li>
  `;

  // First page
  if (current_page > window + 1) {
    pagesHtml += `<li><a href="#" class="ajax-page-link" data-page="1">1</a></li>`;
    if (current_page > window + 2) pagesHtml += `<li class="disabled"><span>...</span></li>`;
  }

  // Page numbers
  for (let i = Math.max(1, current_page - window); i <= Math.min(total_pages, current_page + window); i++) {
    pagesHtml += `
      <li class="${i === current_page ? 'active' : ''}">
        <a href="#" class="ajax-page-link" data-page="${i}">${i}</a>
      </li>
    `;
  }

  // Last page
  if (current_page < total_pages - window) {
    if (current_page < total_pages - window - 1) pagesHtml += `<li class="disabled"><span>...</span></li>`;
    pagesHtml += `<li><a href="#" class="ajax-page-link" data-page="${total_pages}">${total_pages}</a></li>`;
  }

  // Next
  pagesHtml += `
    <li class="${current_page === total_pages ? 'disabled' : ''}">
      <a href="#" class="ajax-page-link" data-page="${current_page + 1}">Next »</a>
    </li>
  `;

  const html = `
    <div class="text-center">
      <ul class="pagination" style="margin: 0;">
        ${pagesHtml}
      </ul>
    </div>
  `;

  bottomContainer.html(html);
  topContainer.html(html);

  // Attach handlers
  $('.ajax-page-link').click(function (e) {
    e.preventDefault();
    if ($(this).parent().hasClass('disabled') || $(this).parent().hasClass('active')) return;

    const newPage = $(this).data('page');
    updateUrlAndReload(query, startYear, endYear, newPage, perPage, sort);
  });
}

function updateUrlAndReload(query, startYear, endYear, page, perPage, sort) {
  loadFilteredResults(query, startYear, endYear, page, perPage, sort);

  // Update URL
  const url = new URL(window.location.href);
  url.searchParams.set('page', page);
  url.searchParams.set('per_page', perPage);
  url.searchParams.set('sort', sort);
  window.history.pushState({ path: url.toString() }, '', url.toString());

  $('html, body').animate({ scrollTop: 0 }, 300);
}
