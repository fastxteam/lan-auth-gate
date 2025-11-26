// 全局变量
let apis = [];
let currentConfirmAction = null;
let currentConfirmData = null;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    loadApis();
    // 绑定确认按钮事件
    document.getElementById('confirmActionBtn').addEventListener('click', executeConfirmAction);
});

// 加载API列表
async function loadApis() {
    try {
        showLoading();
        const response = await fetch('/api/auth/list');
        apis = await response.json();
        renderApiTable(apis);
        updateStats();
        await loadLogs();
        hideLoading();
    } catch (error) {
        console.error('加载API列表失败:', error);
        showError('加载API列表失败');
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

// 隐藏加载状态
function hideLoading() {
    // 加载状态会在renderApiTable中被替换
}

// 显示错误信息
function showError(message) {
    showToast(message, 'error');
}

// 渲染API表格
function renderApiTable(apiList) {
    const tbody = document.getElementById('apiTableBody');
    const emptyState = document.getElementById('emptyState');
    
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
        
        // 在 renderApiTable 函数中确保按钮结构正确
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

// 更新统计信息
function updateStats() {
    const total = apis.length;
    const enabled = apis.filter(api => api.enabled).length;
    const disabled = total - enabled;

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
async function loadLogs() {
    try {
        const response = await fetch('/api/auth/logs');
        const logs = await response.json();
        renderLogs(logs);
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