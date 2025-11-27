// 全局变量
let apis = [];
let currentConfirmAction = null;
let currentConfirmData = null;
let isLoggedIn = false;
// 添加SSE相关变量
let eventSource = null;
let sseReconnectAttempts = 0;
const MAX_SSE_RECONNECT_ATTEMPTS = 10;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    loadApis();
    // 绑定确认按钮事件
    document.getElementById('confirmActionBtn').addEventListener('click', executeConfirmAction);
});

// 修改loadApis函数，确保正确更新统计
async function loadApis() {
    try {
        showLoading();
        const apis = await makeAuthenticatedRequest('/api/auth/list');
        console.log('加载的API数据:', apis); // 调试信息
        renderApiTable(apis);
        updateStats(apis); // 确保传递数据
        await loadLogs();
        hideLoading();
    } catch (error) {
        console.error('加载API列表失败:', error);
        showError('加载API列表失败: ' + error.message);
        hideLoading();
    }
}

// 显示加载状态
function showLoading() {
    const tbody = document.getElementById('apiTableBody');
    tbody.innerHTML = `
        <tr class="loading">
            <td colspan="6" style="text-align: center; padding: 40px;">
                <i class="fas fa-spinner fa-spin" style="font-size: 24px; margin-right: 10px;"></i>
                加载中...
            </td>
        </tr>
    `;
}

// 改进的认证检查函数
async function checkLoginStatus() {
    try {
        const response = await fetch('/api/auth/list', {
            credentials: 'include'  // 确保包含cookies
        });

        if (response.ok) {
            isLoggedIn = true;
            return true;
        } else if (response.status === 401) {
            isLoggedIn = false;
            // 如果未登录，跳转到登录页面
            window.location.href = '/login';
            return false;
        } else {
            isLoggedIn = false;
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('检查登录状态失败:', error);
        isLoggedIn = false;
        // 网络错误也跳转到登录页
        window.location.href = '/login';
        return false;
    }
}

// 隐藏加载状态
function hideLoading() {
    // 加载状态会在renderApiTable中被替换
}

// 显示错误信息
function showError(message) {
    showToast(message, 'error');
}

// 修改renderApiTable函数，确保调用updateStats
function renderApiTable(apiList) {
    const tbody = document.getElementById('apiTableBody');
    const emptyState = document.getElementById('emptyState');

    console.log('渲染表格，数据:', apiList); // 调试信息

    if (apiList.length === 0) {
        tbody.innerHTML = '';
        emptyState.style.display = 'block';
        return;
    }

    emptyState.style.display = 'none';
    tbody.innerHTML = '';

    apiList.forEach(api => {
        const row = document.createElement('tr');
        const escapedPath = api.api_path.replace(/'/g, "\\'").replace(/"/g, '&quot;');
        const escapedDesc = (api.description || '').replace(/'/g, "\\'").replace(/"/g, '&quot;');

        row.innerHTML = `
            <td>
                <div class="call-count-container">
                    <span class="call-count">${api.call_count || 0}</span>
                    <button class="btn-icon reset-count" onclick="resetCallCount(${api.id})" title="重置计数">
                        <i class="fas fa-redo-alt"></i>
                    </button>
                </div>
            </td>
            <td><code>${api.api_path}</code></td>
            <td>${api.description || '-'}</td>
            <td>
                <span class="status-badge ${api.enabled ? 'status-enabled' : 'status-disabled'}">
                    <i class="fas fa-${api.enabled ? 'check-circle' : 'times-circle'}"></i>
                    ${api.enabled ? '启用' : '禁用'}
                </span>
            </td>
            <td>${formatDateTime(api.created_at)}</td>
            <td>
                <div class="action-buttons">
                    <button class="action-btn ${api.enabled ? 'disable' : 'enable'}" onclick="toggleApi(${api.id}, ${!api.enabled})">
                        <i class="fas fa-${api.enabled ? 'pause' : 'play'}"></i>
                        ${api.enabled ? '禁用' : '启用'}
                    </button>
                    <button class="action-btn edit" onclick="editApi(${api.id}, '${escapedPath}', '${escapedDesc}', ${api.enabled})">
                        <i class="fas fa-edit"></i>
                        编辑
                    </button>
                    <button class="action-btn delete" onclick="deleteApi(${api.id})">
                        <i class="fas fa-trash"></i>
                        删除
                    </button>
                </div>
            </td>
        `;
        tbody.appendChild(row);
    });

    // 确保统计信息更新
    updateStats(apiList);
}

// 格式化日期时间
function formatDateTime(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// 修改updateStats函数，确保正确计算
function updateStats(apis = []) {
    console.log('更新统计，数据长度:', apis.length); // 调试信息

    const total = apis.length;
    const enabled = apis.filter(api => api.enabled).length;
    const disabled = total - enabled;

    console.log('统计结果 - 总数:', total, '启用:', enabled, '禁用:', disabled); // 调试信息

    document.getElementById('totalApis').textContent = total;
    document.getElementById('enabledApis').textContent = enabled;
    document.getElementById('disabledApis').textContent = disabled;
}

// 切换API状态
async function toggleApi(apiId, enabled) {
    try {
        const response = await fetch(`/api/auth/update/${apiId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ enabled: enabled })
        });

        if (response.ok) {
            await loadApis();
            showToast(enabled ? 'API已启用' : 'API已禁用', 'success');
        } else {
            showToast('更新API状态失败', 'error');
        }
    } catch (error) {
        console.error('更新API状态失败:', error);
        showToast('更新API状态失败', 'error');
    }
}

// 删除API
function deleteApi(apiId) {
    showConfirm('deleteApi', '确定要删除这个API吗？此操作不可撤销。', apiId);
}

async function deleteApiConfirmed(apiId) {
    try {
        const response = await fetch(`/api/auth/delete/${apiId}`, {
            method: 'DELETE'
        });

        if (response.ok) {
            await loadApis();
            showToast('API删除成功', 'success');
        } else {
            showToast('删除API失败', 'error');
        }
    } catch (error) {
        console.error('删除API失败:', error);
        showToast('删除API失败', 'error');
    }
}

// 编辑API
function editApi(apiId, currentPath, currentDescription, currentEnabled) {
    document.getElementById('editApiId').value = apiId;
    document.getElementById('editApiPath').value = currentPath;
    document.getElementById('editDescription').value = currentDescription || '';
    document.getElementById('editEnabled').value = currentEnabled ? 'true' : 'false';
    document.getElementById('editModal').style.display = 'block';
}

function hideEditModal() {
    document.getElementById('editModal').style.display = 'none';
}

async function saveEdit() {
    const apiId = document.getElementById('editApiId').value;
    const apiPath = document.getElementById('editApiPath').value.trim();
    const description = document.getElementById('editDescription').value.trim();
    const enabled = document.getElementById('editEnabled').value === 'true';
    
    if (!apiPath) {
        showToast('请输入API路径', 'error');
        return;
    }
    
    if (!apiPath.startsWith('/')) {
        showToast('API路径必须以斜杠(/)开头', 'error');
        return;
    }

    try {
        const response = await fetch(`/api/auth/update/${apiId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                api_path: apiPath,
                description: description,
                enabled: enabled
            })
        });

        if (response.ok) {
            hideEditModal();
            await loadApis();
            showToast('API更新成功', 'success');
        } else {
            const result = await response.json();
            showToast(result.error || '更新失败', 'error');
        }
    } catch (error) {
        console.error('更新API失败:', error);
        showToast('更新API失败', 'error');
    }
}

// 添加API
function showAddModal() {
    document.getElementById('addModal').style.display = 'block';
    document.getElementById('addForm').reset();
    document.getElementById('apiPath').focus();
}

function hideAddModal() {
    document.getElementById('addModal').style.display = 'none';
}

async function addApi() {
    const apiPath = document.getElementById('apiPath').value.trim();
    const description = document.getElementById('description').value.trim();
    const enabled = document.getElementById('enabled').value === 'true';

    if (!apiPath) {
        showToast('请输入API路径', 'error');
        return;
    }

    if (!apiPath.startsWith('/')) {
        showToast('API路径必须以斜杠(/)开头', 'error');
        return;
    }

    try {
        const response = await fetch('/api/auth/add', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                api_path: apiPath,
                description: description,
                enabled: enabled
            })
        });

        const result = await response.json();

        if (response.ok) {
            hideAddModal();
            await loadApis();
            showToast('API添加成功', 'success');
        } else {
            showToast(result.error || '添加API失败', 'error');
        }
    } catch (error) {
        console.error('添加API失败:', error);
        showToast('添加API失败', 'error');
    }
}

// 导出配置
async function exportConfig() {
    try {
        const response = await fetch('/api/auth/export');
        const result = await response.json();

        if (response.ok) {
            showToast(`配置已导出到: ${result.export_path}`, 'success');
            loadLogs();
        } else {
            showToast(result.error || '导出失败', 'error');
        }
    } catch (error) {
        console.error('导出配置失败:', error);
        showToast('导出配置失败', 'error');
    }
}

// 导入配置
function showImportModal() {
    document.getElementById('importModal').style.display = 'block';
    document.getElementById('importFile').value = '';
}

function hideImportModal() {
    document.getElementById('importModal').style.display = 'none';
}

async function importConfig() {
    const fileInput = document.getElementById('importFile');
    const file = fileInput.files[0];

    if (!file) {
        showToast('请选择要导入的文件', 'error');
        return;
    }

    if (!file.name.endsWith('.json')) {
        showToast('请选择JSON格式的文件', 'error');
        return;
    }

    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch('/api/auth/import', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (response.ok) {
            hideImportModal();
            await loadApis();
            showToast('配置导入成功', 'success');
        } else {
            showToast(result.error || '导入配置失败', 'error');
        }
    } catch (error) {
        console.error('导入配置失败:', error);
        showToast('导入配置失败', 'error');
    }
}

// 调用次数管理
function resetCallCount(apiId) {
    showConfirm('resetCallCount', '确定要重置这个API的调用次数吗？', apiId);
}

async function resetCallCountConfirmed(apiId) {
    try {
        const response = await fetch(`/api/auth/reset-call-count/${apiId}`, {
            method: 'POST'
        });
        
        if (response.ok) {
            await loadApis();
            showToast('调用次数已重置', 'success');
        } else {
            showToast('重置失败', 'error');
        }
    } catch (error) {
        console.error('重置调用次数失败:', error);
        showToast('重置失败', 'error');
    }
}

function resetAllCallCounts() {
    showConfirm('resetAllCallCounts', '确定要重置所有API的调用次数吗？');
}

async function resetAllCallCountsConfirmed() {
    try {
        const response = await fetch('/api/auth/reset-all-call-counts', {
            method: 'POST'
        });
        
        if (response.ok) {
            await loadApis();
            showToast('所有调用次数已重置', 'success');
        } else {
            showToast('重置失败', 'error');
        }
    } catch (error) {
        console.error('重置所有调用次数失败:', error);
        showToast('重置失败', 'error');
    }
}

// 搜索API
function searchApis() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    const filteredApis = apis.filter(api => 
        api.api_path.toLowerCase().includes(searchTerm) ||
        (api.description && api.description.toLowerCase().includes(searchTerm))
    );
    renderApiTable(filteredApis);
}

// 日志管理
// 修改刷新日志函数
async function loadLogs() {
    try {
        const response = await fetch('/api/auth/logs?limit=20');
        const logs = await response.json();
        renderInitialLogs(logs);
    } catch (error) {
        console.error('加载日志失败:', error);
    }
}

function renderLogs(logs) {
    const logsContent = document.getElementById('logsContent');
    if (!logsContent) return;
    
    logsContent.innerHTML = '';
    
    if (logs.length === 0) {
        logsContent.innerHTML = '<div class="log-entry">暂无日志记录</div>';
        return;
    }
    
    logs.forEach(log => {
        const logEntry = document.createElement('div');
        logEntry.className = 'log-entry';
        logEntry.innerHTML = `
            <span class="log-time">${log.timestamp}</span>
            <span class="log-ip">${log.ip_address}</span>
            <span class="log-action">${log.action}</span>
            <span class="log-details">${log.details}</span>
        `;
        logsContent.appendChild(logEntry);
    });
    
    // 自动滚动到底部
    logsContent.scrollTop = logsContent.scrollHeight;
}

// 修改清除日志函数，清除后重新初始化流
async function clearLogs() {
    try {
        const response = await fetch('/api/auth/clear-logs', {
            method: 'DELETE'
        });
        
        if (response.ok) {
            await loadLogs();
            showToast('日志已清除', 'success');
        } else {
            showToast('清除日志失败', 'error');
        }
    } catch (error) {
        console.error('清除日志失败:', error);
        showToast('清除日志失败', 'error');
    }
}



// 修改initLogStream函数为SSE版本
function initLogStream() {
    // 关闭现有的SSE连接
    if (eventSource) {
        eventSource.close();
        eventSource = null;
    }

    // 构建SSE URL
    const sseUrl = '/api/auth/logs/stream';
    console.log('🔗 连接SSE:', sseUrl);

    try {
        eventSource = new EventSource(sseUrl, { withCredentials: true });

        eventSource.onopen = function() {
            console.log('✅ SSE连接已建立');
            sseReconnectAttempts = 0;
            updateLogConnectionStatus(true);
        };

        eventSource.onmessage = function(event) {
            try {
                const data = JSON.parse(event.data);

                // 处理心跳包
                if (data.type === 'heartbeat') {
                    console.log('💓 SSE心跳:', new Date().toLocaleTimeString());
                    return;
                }

                // 处理日志数据
                console.log('📨 收到日志:', data);
                addNewLogToDisplay(data);

            } catch (error) {
                console.error('❌ 解析SSE数据失败:', error, '原始数据:', event.data);
            }
        };

        eventSource.onerror = function(event) {
            console.error('❌ SSE连接错误:', event);
            updateLogConnectionStatus(false);

            // SSE会自动重连，但我们也可以手动控制
            if (eventSource.readyState === EventSource.CLOSED) {
                sseReconnectAttempts++;
                console.log(`SSE连接关闭，重试次数: ${sseReconnectAttempts}/${MAX_SSE_RECONNECT_ATTEMPTS}`);

                if (sseReconnectAttempts >= MAX_SSE_RECONNECT_ATTEMPTS) {
                    console.error('🚫 达到最大SSE重连次数，停止尝试');
                    showToast('实时日志连接失败', 'error');
                    eventSource.close();
                }
            }
        };

    } catch (error) {
        console.error('❌ 创建SSE失败:', error);
        updateLogConnectionStatus(false);
    }
}

// 修改页面可见性处理
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        // 页面不可见时关闭SSE以节省资源
        if (eventSource) {
            console.log('⏸️ 页面不可见，关闭SSE');
            eventSource.close();
            updateLogConnectionStatus(false);
        }
    } else {
        // 页面可见时重新连接
        if (!eventSource || eventSource.readyState === EventSource.CLOSED) {
            console.log('▶️ 页面可见，重新连接SSE');
            initLogStream();
        }
    }
});

// 修改手动重连函数
function reconnectSSE() {
    console.log('手动重新连接SSE...');
    if (eventSource) {
        eventSource.close();
    }
    initLogStream();
}

// 修改addNewLogToDisplay函数
function addNewLogToDisplay(log) {
    const logsContent = document.getElementById('logsContent');
    if (!logsContent) return;

    // 处理心跳包
    if (log.type === 'heartbeat') {
        // 可以选择不显示心跳包，或者以不同样式显示
        // console.log('💓 心跳包:', log.timestamp);
        return;
    }

    const logEntry = document.createElement('div');
    logEntry.className = 'log-entry';

    // 如果是测试消息，添加特殊样式
    if (log.type === 'test') {
        logEntry.classList.add('heartbeat');
    }

    logEntry.innerHTML = `
        <span class="log-time">${log.timestamp}</span>
        <span class="log-ip">${log.ip_address || 'N/A'}</span>
        <span class="log-action">${log.action}</span>
        <span class="log-details">${log.details}</span>
    `;

    // 插入到顶部
    if (logsContent.firstChild) {
        logsContent.insertBefore(logEntry, logsContent.firstChild);
    } else {
        logsContent.appendChild(logEntry);
    }

    // 限制日志数量，避免过多
    const maxLogs = 100;
    const allLogs = logsContent.querySelectorAll('.log-entry');
    if (allLogs.length > maxLogs) {
        for (let i = maxLogs; i < allLogs.length; i++) {
            allLogs[i].remove();
        }
    }

    // 添加新日志高亮效果
    if (log.type !== 'test') {
        logEntry.style.backgroundColor = 'hsl(142 76% 97%)';
        setTimeout(() => {
            logEntry.style.backgroundColor = '';
        }, 2000);
    }
}

// 更新连接状态显示函数
function updateLogConnectionStatus(connected) {
    const logsHeader = document.querySelector('.logs-header h3');
    if (logsHeader) {
        if (connected) {
            logsHeader.innerHTML = '<i class="fas fa-history"></i> 操作日志 <span class="connection-status connected"><i class="fas fa-broadcast-tower"></i> 实时(SSE)</span>';
        } else {
            logsHeader.innerHTML = '<i class="fas fa-history"></i> 操作日志 <span class="connection-status disconnected"><i class="fas fa-broadcast-tower"></i> 连接中...</span>';
        }
    }
}

// 添加网络状态监听
window.addEventListener('online', function() {
    console.log('🌐 网络连接恢复，重新连接SSE');
    if (!eventSource || eventSource.readyState === EventSource.CLOSED) {
        initLogStream();
    }
});

window.addEventListener('offline', function() {
    console.log('🌐 网络连接断开');
    if (eventSource) {
        eventSource.close();
        updateLogConnectionStatus(false);
    }
});

// 修改页面加载逻辑
document.addEventListener('DOMContentLoaded', async function() {
    // 检查当前页面路径
    if (window.location.pathname === '/login') {
        // 在登录页面，不执行主页面逻辑
        return;
    }

    // 在主页面，检查登录状态并加载数据
    try {
        const response = await fetch('/api/auth/check-session', {
            credentials: 'include'
        });

        if (response.ok) {
            // 已登录，加载数据
            await loadApis();
            initLogStream();
        } else {
            // 未登录，跳转到登录页面
            window.location.href = '/login';
        }
    } catch (error) {
        console.error('检查登录状态失败:', error);
        window.location.href = '/login';
    }

    // 绑定确认按钮事件
    document.getElementById('confirmActionBtn').addEventListener('click', executeConfirmAction);
});

// 修改所有API调用函数，确保包含credentials
async function makeAuthenticatedRequest(url, options = {}) {
    try {
        const response = await fetch(url, {
            credentials: 'include',  // 重要：包含cookies
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        });

        if (response.status === 401) {
            // 未授权，跳转到登录页面
            window.location.href = '/login';
            throw new Error('需要登录');
        }

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.detail || '请求失败');
        }

        return await response.json();
    } catch (error) {
        console.error('API请求失败:', error);
        throw error;
    }
}

// 页面不可见时暂停日志更新
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        // 页面不可见时暂停日志流
        if (eventSource) {
            eventSource.close();
            isLogStreamConnected = false;
            updateLogConnectionStatus(false);
        }
    } else {
        // 页面可见时重新连接
        if (!isLogStreamConnected) {
            initLogStream();
        }
    }
});

// 渲染初始日志
function renderInitialLogs(logs) {
    const logsContent = document.getElementById('logsContent');
    if (!logsContent) return;

    logsContent.innerHTML = '';

    if (logs.length === 0) {
        logsContent.innerHTML = '<div class="log-entry">暂无日志记录</div>';
        return;
    }

    logs.forEach(log => {
        const logEntry = document.createElement('div');
        logEntry.className = 'log-entry';
        logEntry.innerHTML = `
            <span class="log-time">${log.timestamp}</span>
            <span class="log-ip">${log.ip_address}</span>
            <span class="log-action">${log.action}</span>
            <span class="log-details">${log.details}</span>
        `;
        logsContent.appendChild(logEntry);
    });
}

// 退出登录
async function logout() {
    try {
        const response = await fetch('/api/auth/logout', {
            method: 'POST'
        });
        
        if (response.ok) {
            window.location.href = '/';
        }
    } catch (error) {
        console.error('退出失败:', error);
    }
}

// 自定义确认弹窗
function showConfirm(action, message, data = null) {
    const modal = document.getElementById('confirmModal');
    const messageEl = document.getElementById('confirmMessage');
    const actionBtn = document.getElementById('confirmActionBtn');
    
    currentConfirmAction = action;
    currentConfirmData = data;
    messageEl.textContent = message;
    
    // 根据操作设置按钮文本和样式
    if (action === 'logout') {
        actionBtn.textContent = '退出';
        actionBtn.className = 'btn btn-primary';
    } else if (action === 'clearLogs') {
        actionBtn.textContent = '清除';
        actionBtn.className = 'btn btn-danger';
    } else if (action === 'deleteApi') {
        actionBtn.textContent = '删除';
        actionBtn.className = 'btn btn-danger';
    } else if (action === 'resetAllCallCounts') {
        actionBtn.textContent = '重置';
        actionBtn.className = 'btn btn-primary';
    } else if (action === 'resetCallCount') {
        actionBtn.textContent = '重置';
        actionBtn.className = 'btn btn-primary';
    } else {
        actionBtn.textContent = '确定';
        actionBtn.className = 'btn btn-primary';
    }
    
    modal.style.display = 'block';
}

function hideConfirm() {
    const modal = document.getElementById('confirmModal');
    modal.style.display = 'none';
    currentConfirmAction = null;
    currentConfirmData = null;
}

function executeConfirmAction() {
    if (!currentConfirmAction) return;
    
    if (currentConfirmAction === 'logout') {
        logout();
    } else if (currentConfirmAction === 'clearLogs') {
        clearLogs();
    } else if (currentConfirmAction === 'deleteApi') {
        deleteApiConfirmed(currentConfirmData);
    } else if (currentConfirmAction === 'resetAllCallCounts') {
        resetAllCallCountsConfirmed();
    } else if (currentConfirmAction === 'resetCallCount') {
        resetCallCountConfirmed(currentConfirmData);
    }
    
    hideConfirm();
}

// 显示Toast提示
function showToast(message, type = 'info') {
    // 移除现有的toast
    const existingToasts = document.querySelectorAll('.toast');
    existingToasts.forEach(toast => {
        toast.style.animation = 'toastFadeOut 0.3s ease';
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    });

    // 创建新的toast
    setTimeout(() => {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;

        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.animation = 'toastFadeOut 0.3s ease';
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.parentNode.removeChild(toast);
                }
            }, 300);
        }, 3000);
    }, 100);
}

// 在 script.js 中添加修改密码功能

// 显示修改密码模态框
function showChangePasswordModal() {
    // 创建修改密码模态框
    const modalHtml = `
        <div id="changePasswordModal" class="modal" style="display: block;">
            <div class="modal-content">
                <div class="modal-header">
                    <h2><i class="fas fa-key"></i> 修改密码</h2>
                    <span class="close" onclick="hideChangePasswordModal()">&times;</span>
                </div>
                <div class="modal-body">
                    <form id="changePasswordForm">
                        <div class="form-group">
                            <label for="currentPassword">当前密码:</label>
                            <input type="password" id="currentPassword" required>
                        </div>
                        <div class="form-group">
                            <label for="newPassword">新密码:</label>
                            <input type="password" id="newPassword" required minlength="4">
                            <p class="help-text">密码长度至少4位</p>
                        </div>
                        <div class="form-group">
                            <label for="confirmPassword">确认新密码:</label>
                            <input type="password" id="confirmPassword" required minlength="4">
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button class="btn" onclick="hideChangePasswordModal()">取消</button>
                    <button class="btn btn-primary" onclick="changePassword()">修改密码</button>
                </div>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalHtml);
}

// 隐藏修改密码模态框
function hideChangePasswordModal() {
    const modal = document.getElementById('changePasswordModal');
    if (modal) {
        modal.remove();
    }
}

// 修改密码
async function changePassword() {
    const currentPassword = document.getElementById('currentPassword').value;
    const newPassword = document.getElementById('newPassword').value;
    const confirmPassword = document.getElementById('confirmPassword').value;

    if (!currentPassword || !newPassword || !confirmPassword) {
        showToast('请填写所有字段', 'error');
        return;
    }

    if (newPassword !== confirmPassword) {
        showToast('新密码和确认密码不一致', 'error');
        return;
    }

    if (newPassword.length < 4) {
        showToast('密码长度至少4位', 'error');
        return;
    }

    try {
        const response = await fetch('/api/auth/change-password', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                current_password: currentPassword,
                new_password: newPassword,
                confirm_password: confirmPassword
            })
        });

        const result = await response.json();

        if (result.success) {
            hideChangePasswordModal();
            showToast('密码修改成功', 'success');
            // 可选：强制重新登录
            // setTimeout(() => { logout(); }, 2000);
        } else {
            showToast(result.message, 'error');
        }
    } catch (error) {
        console.error('修改密码失败:', error);
        showToast('修改密码失败', 'error');
    }
}

// 在工具栏添加修改密码按钮（可选）
// 可以在 toolbar 部分添加：
// <button class="btn" onclick="showChangePasswordModal()">
//     <i class="fas fa-key"></i> 修改密码
// </button>



// 点击模态框外部关闭
window.onclick = function(event) {
    const addModal = document.getElementById('addModal');
    const editModal = document.getElementById('editModal');
    const importModal = document.getElementById('importModal');
    const confirmModal = document.getElementById('confirmModal');
    
    if (event.target === addModal) hideAddModal();
    if (event.target === editModal) hideEditModal();
    if (event.target === importModal) hideImportModal();
    if (event.target === confirmModal) hideConfirm();
}

// 键盘快捷键
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        hideAddModal();
        hideEditModal();
        hideImportModal();
        hideConfirm();
    }
    
    if (event.ctrlKey && event.key === 'n') {
        event.preventDefault();
        showAddModal();
    }
    
    if (event.ctrlKey && event.key === 'f') {
        event.preventDefault();
        document.getElementById('searchInput').focus();
    }
});