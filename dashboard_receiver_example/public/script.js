// ===== GLOBAL VARIABLES =====
let allTransactions = [];
let autoRefreshInterval = null;
const basePath = window.location.pathname.startsWith('/dashboard') ? '/dashboard' : '';
const API_BASE = `${window.location.origin}${basePath}`;

const groupNameEl = document.getElementById('groupName');
const groupNameBadge = document.getElementById('groupNameBadge');
const groupIdBadge = document.getElementById('groupIdBadge');
const logoutButton = document.getElementById('logoutButton');

// ===== INITIALIZATION =====
document.addEventListener('DOMContentLoaded', function() {
    console.log('Dashboard loaded');
    loadGroupInfo();
    loadData();

    if (logoutButton) {
        logoutButton.addEventListener('click', async () => {
            try {
                await fetch(`${API_BASE}/logout`, { method: 'POST' });
            } catch (_) {
                // ignore logout failures
            }
            window.location.href = `${basePath}/login`;
        });
    }

    if (document.getElementById('autoRefresh').checked) {
        startAutoRefresh();
    }
});

async function loadGroupInfo() {
    try {
        const response = await fetch(`${API_BASE}/group-info`);
        if (response.status === 401) {
            window.location.href = `${basePath}/login`;
            return;
        }

        const data = await response.json();
        if (data.success && data.data) {
            const name = data.data.nama_group || 'Group';
            const gid = data.data.gid || '-';
            if (groupNameEl) groupNameEl.textContent = name;
            if (groupNameBadge) groupNameBadge.textContent = name;
            if (groupIdBadge) groupIdBadge.textContent = gid;
        }
    } catch (error) {
        console.error('Error loading group info:', error);
    }
}

// ===== LOAD DATA =====
async function loadData() {
    try {
        showRefreshAnimation();

        // Fetch stats
        const statsResponse = await fetch(`${API_BASE}/stats`);
        if (statsResponse.status === 401) {
            window.location.href = `${basePath}/login`;
            return;
        }
        const statsData = await statsResponse.json();

        if (statsData.success) {
            updateStats(statsData.data);
        }

        // Fetch transactions
        const transactionsResponse = await fetch(`${API_BASE}/transactions`);
        if (transactionsResponse.status === 401) {
            window.location.href = `${basePath}/login`;
            return;
        }
        const transactionsData = await transactionsResponse.json();

        if (transactionsData.success) {
            allTransactions = transactionsData.data.transactions || [];
            populateFilters();
            filterTransactions();
            updateLastUpdate();
        }

        hideRefreshAnimation();
        setConnectionStatus(true);

    } catch (error) {
        console.error('Error loading data:', error);
        showToast('Gagal memuat data: ' + error.message, 'error');
        hideRefreshAnimation();
        setConnectionStatus(false);
    }
}

// ===== UPDATE STATS =====
function updateStats(stats) {
    document.getElementById('totalTransactions').textContent = stats.total_transactions || 0;

    // Format revenue
    const revenueIDR = stats.total_revenue?.IDR || 0;
    document.getElementById('totalRevenue').textContent = formatCurrency(revenueIDR);

    // Platform counts
    document.getElementById('tiktokCount').textContent = stats.by_platform?.TIKTOK || 0;
    document.getElementById('shopeeCount').textContent = stats.by_platform?.SHOPEE || 0;
}

// ===== POPULATE FILTERS =====
function populateFilters() {
    const shopFilter = document.getElementById('filterShop');
    const shops = new Set();

    allTransactions.forEach(t => {
        if (t.shop_id) {
            shops.add(t.shop_id);
        }
    });

    // Clear existing options except first one
    shopFilter.innerHTML = '<option value="">Semua Toko</option>';

    shops.forEach(shop => {
        const option = document.createElement('option');
        option.value = shop;
        option.textContent = shop;
        shopFilter.appendChild(option);
    });
}

// ===== FILTER TRANSACTIONS =====
function filterTransactions() {
    const platformFilter = document.getElementById('filterPlatform').value;
    const shopFilter = document.getElementById('filterShop').value;
    const searchQuery = document.getElementById('searchOrder').value.toLowerCase();

    let filtered = allTransactions;

    // Filter by platform
    if (platformFilter) {
        filtered = filtered.filter(t => t.platform === platformFilter);
    }

    // Filter by shop
    if (shopFilter) {
        filtered = filtered.filter(t => t.shop_id === shopFilter);
    }

    // Search by order ID
    if (searchQuery) {
        filtered = filtered.filter(t =>
            t.order_id.toLowerCase().includes(searchQuery)
        );
    }

    displayTransactions(filtered);
}

// ===== DISPLAY TRANSACTIONS =====
function displayTransactions(transactions) {
    const tbody = document.getElementById('transactionsBody');
    const noData = document.getElementById('noData');

    if (transactions.length === 0) {
        tbody.innerHTML = '';
        noData.style.display = 'block';
        return;
    }

    noData.style.display = 'none';

    // Sort by create_time descending (newest first)
    transactions.sort((a, b) => b.create_time - a.create_time);

    tbody.innerHTML = transactions.map((t, index) => `
        <tr>
            <td>${index + 1}</td>
            <td><strong>${t.order_id}</strong></td>
            <td>
                <span class="badge ${t.platform === 'TIKTOK' ? 'badge-tiktok' : 'badge-shopee'}">
                    ${t.platform}
                </span>
            </td>
            <td><small>${t.shop_id || '-'}</small></td>
            <td>
                <span class="status-badge ${getStatusClass(t.order_status)}">
                    ${formatStatus(t.order_status)}
                </span>
            </td>
            <td><strong>${formatCurrency(parseFloat(t.total_amount) || 0)}</strong></td>
            <td>${t.items_count || t.items?.length || 0} item</td>
            <td>${formatDate(t.create_time)}</td>
            <td>
                <button class="btn-detail" onclick='showDetail(${JSON.stringify(t).replace(/'/g, "&#39;")})'>
                     Detail
                </button>
            </td>
        </tr>
    `).join('');
}

// ===== SHOW DETAIL MODAL =====
function showDetail(transaction) {
    const modal = document.getElementById('detailModal');
    const modalBody = document.getElementById('modalBody');

    const items = transaction.items || [];

    modalBody.innerHTML = `
        <div class="detail-group">
            <h3> Informasi Order</h3>
            <div class="detail-row">
                <strong>Order ID:</strong>
                <span>${transaction.order_id}</span>
            </div>
            <div class="detail-row">
                <strong>Platform:</strong>
                <span class="badge ${transaction.platform === 'TIKTOK' ? 'badge-tiktok' : 'badge-shopee'}">
                    ${transaction.platform}
                </span>
            </div>
            <div class="detail-row">
                <strong>Shop ID:</strong>
                <span>${transaction.shop_id || '-'}</span>
            </div>
            <div class="detail-row">
                <strong>Status:</strong>
                <span class="status-badge ${getStatusClass(transaction.order_status)}">
                    ${formatStatus(transaction.order_status)}
                </span>
            </div>
            <div class="detail-row">
                <strong>Total Amount:</strong>
                <span><strong>${formatCurrency(parseFloat(transaction.total_amount) || 0)}</strong></span>
            </div>
            <div class="detail-row">
                <strong>Currency:</strong>
                <span>${transaction.currency || 'IDR'}</span>
            </div>
        </div>

        <div class="detail-group">
            <h3> Tanggal</h3>
            <div class="detail-row">
                <strong>Create Time:</strong>
                <span>${formatDate(transaction.create_time)}</span>
            </div>
            <div class="detail-row">
                <strong>Update Time:</strong>
                <span>${formatDate(transaction.update_time)}</span>
            </div>
            <div class="detail-row">
                <strong>Paid Date:</strong>
                <span>${transaction.paid_date || '-'}</span>
            </div>
            <div class="detail-row">
                <strong>Received At (Dashboard):</strong>
                <span>${transaction.received_at ? new Date(transaction.received_at).toLocaleString('id-ID') : '-'}</span>
            </div>
        </div>

        <div class="detail-group">
            <h3> Customer Info</h3>
            <div class="detail-row">
                <strong>Buyer Name:</strong>
                <span>${transaction.buyer_name || '-'}</span>
            </div>
            <div class="detail-row">
                <strong>Tracking Number:</strong>
                <span>${transaction.tracking_number || '-'}</span>
            </div>
        </div>

        <div class="detail-group">
            <h3> Items (${items.length})</h3>
            <div class="items-list">
                ${items.length === 0 ? '<p style="color: #6b7280;">No items data</p>' : ''}
                ${items.map((item, i) => `
                    <div class="item-card">
                        <h4>Item ${i + 1}: ${item.product_name || 'Unnamed Product'}</h4>
                        <p><strong>Product ID:</strong> ${item.product_id || '-'}</p>
                        <p><strong>SKU ID:</strong> ${item.sku_id || '-'}</p>
                        <p><strong>Seller SKU:</strong> ${item.seller_sku || '-'}</p>
                        <p><strong>Quantity:</strong> ${item.quantity || 0}</p>
                        <p><strong>Price:</strong> ${formatCurrency(parseFloat(item.price) || 0)}</p>
                        <p><strong>Original Price:</strong> ${formatCurrency(parseFloat(item.original_price) || 0)}</p>
                    </div>
                `).join('')}
            </div>
        </div>
    `;

    modal.classList.add('active');
}

// ===== CLOSE MODAL =====
function closeModal() {
    const modal = document.getElementById('detailModal');
    modal.classList.remove('active');
}

// Close modal when clicking outside
document.getElementById('detailModal')?.addEventListener('click', function(e) {
    if (e.target === this) {
        closeModal();
    }
});

// ===== AUTO REFRESH =====
function toggleAutoRefresh() {
    const isChecked = document.getElementById('autoRefresh').checked;

    if (isChecked) {
        startAutoRefresh();
        showToast('Auto refresh diaktifkan (10 detik)', 'success');
    } else {
        stopAutoRefresh();
        showToast('Auto refresh dinonaktifkan', 'info');
    }
}

function startAutoRefresh() {
    stopAutoRefresh(); // Clear existing interval
    autoRefreshInterval = setInterval(() => {
        console.log(' Auto refresh...');
        loadData();
    }, 10000); // 10 seconds
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

// ===== UTILITY FUNCTIONS =====
function formatCurrency(amount) {
    return new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(amount);
}

function formatDate(timestamp) {
    if (!timestamp) return '-';
    const date = new Date(timestamp * 1000);
    return date.toLocaleString('id-ID', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function formatStatus(status) {
    const statusMap = {
        'DELIVERED': 'Terkirim',
        'IN_TRANSIT': 'Dalam Pengiriman',
        'AWAITING_SHIPMENT': 'Menunggu Pengiriman',
        'CANCELLED': 'Dibatalkan',
        'UNPAID': 'Belum Bayar'
    };
    return statusMap[status] || status;
}

function getStatusClass(status) {
    const statusClasses = {
        'DELIVERED': 'status-delivered',
        'IN_TRANSIT': 'status-in-transit',
        'AWAITING_SHIPMENT': 'status-awaiting',
        'CANCELLED': 'status-cancelled',
        'UNPAID': 'status-awaiting'
    };
    return statusClasses[status] || 'status-awaiting';
}

function updateLastUpdate() {
    const now = new Date();
    document.getElementById('lastUpdate').textContent = now.toLocaleTimeString('id-ID');
}

function setConnectionStatus(isConnected) {
    const statusEl = document.getElementById('connectionStatus');
    if (isConnected) {
        statusEl.textContent = 'Connected';
        statusEl.className = 'status-pill status-connected';
    } else {
        statusEl.textContent = 'Disconnected';
        statusEl.className = 'status-pill status-disconnected';
    }
}

function showRefreshAnimation() {
    const icon = document.getElementById('refreshIcon');
    icon.classList.add('rotating');
}

function hideRefreshAnimation() {
    const icon = document.getElementById('refreshIcon');
    icon.classList.remove('rotating');
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.style.background = type === 'error' ? '#ef4444' :
                            type === 'info' ? '#3b82f6' : '#10b981';
    toast.classList.add('show');

    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// ===== KEYBOARD SHORTCUTS =====
document.addEventListener('keydown', function(e) {
    // ESC to close modal
    if (e.key === 'Escape') {
        closeModal();
    }

    // Ctrl+R to refresh (prevent default browser refresh)
    if (e.ctrlKey && e.key === 'r') {
        e.preventDefault();
        loadData();
    }
});
