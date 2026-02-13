/**
 * 列设置管理器
 * 处理表格列的显示/隐藏配置
 */

class ColumnSettingsManager {
    constructor() {
        this.currentTab = 'access';
        this.currentColumns = [];
        this.savedSettings = this.loadSettings();
    }

    // 从localStorage加载设置
    loadSettings() {
        const saved = localStorage.getItem('column-settings');
        return saved ? JSON.parse(saved) : {};
    }

    // 保存设置到localStorage
    saveSettings() {
        localStorage.setItem('column-settings', JSON.stringify(this.savedSettings));
    }

    // 获取当前tab的列配置
    getCurrentColumns() {
        const tabKey = `columns_${this.currentTab}`;
        
        // 如果没有保存的设置，使用默认配置
        if (!this.savedSettings[tabKey]) {
            return CONFIG.DEFAULT_COLUMNS[this.currentTab];
        }
        
        // 如果有保存的设置，但为空数组，也使用默认配置
        if (Array.isArray(this.savedSettings[tabKey]) && this.savedSettings[tabKey].length === 0) {
            return CONFIG.DEFAULT_COLUMNS[this.currentTab];
        }
        
        return this.savedSettings[tabKey];
    }

    // 保存当前tab的列配置
    saveCurrentColumns(columns) {
        const tabKey = `columns_${this.currentTab}`;
        this.savedSettings[tabKey] = columns;
        this.saveSettings();
    }

    // 打开列设置弹窗
    openSettings(tab) {
        this.currentTab = tab;
        this.currentColumns = [...this.getCurrentColumns()];
        
        // 更新弹窗标题
        const tabName = CONFIG.TAB_CONFIG[tab].text;
        document.getElementById('current-tab-name').textContent = tabName;
        
        // 生成列选项
        this.generateColumnList();
        
        // 显示弹窗
        document.getElementById('column-settings-modal').classList.remove('hidden');
    }

    // 关闭列设置弹窗
    closeSettings() {
        document.getElementById('column-settings-modal').classList.add('hidden');
    }

    // 生成列选项列表
    generateColumnList() {
        const columnList = document.getElementById('column-list');
        const columnConfig = CONFIG.COLUMN_CONFIG['AccessView'];
        
        // 按分组组织列
        const groups = {};
        for (const [key, config] of Object.entries(columnConfig)) {
            const group = config.group || '其他';
            if (!groups[group]) {
                groups[group] = [];
            }
            groups[group].push({ key, ...config });
        }

        // 生成分组HTML
        let html = '';
        for (const [groupName, columns] of Object.entries(groups)) {
            html += `
                <div class="mb-4">
                    <div class="text-xs font-bold text-slate-400 mb-2 uppercase tracking-wider">${groupName}</div>
                    <div class="space-y-1">
            `;
            
            for (const column of columns) {
                const isChecked = this.currentColumns.includes(column.key);
                html += `
                    <div class="flex items-center justify-between p-2 rounded hover:bg-[#161b22] group">
                        <label class="flex items-center gap-2 cursor-pointer flex-1">
                            <input type="checkbox" 
                                   data-column="${column.key}" 
                                   ${isChecked ? 'checked' : ''} 
                                   class="w-3 h-3 text-blue-600 bg-[#010409] border-[#30363d] rounded focus:ring-blue-500/50">
                            <span class="text-xs text-slate-300">${column.name}</span>
                            <span class="text-xs text-slate-500 font-mono">${column.key.replace('AccessView.', '')}</span>
                        </label>
                    </div>
                `;
            }
            
            html += `
                    </div>
                </div>
            `;
        }
        
        columnList.innerHTML = html;
        
        // 添加checkbox事件监听
        columnList.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
            checkbox.addEventListener('change', (e) => {
                const columnKey = e.target.dataset.column;
                if (e.target.checked) {
                    if (!this.currentColumns.includes(columnKey)) {
                        this.currentColumns.push(columnKey);
                    }
                } else {
                    const index = this.currentColumns.indexOf(columnKey);
                    if (index > -1) {
                        this.currentColumns.splice(index, 1);
                    }
                }
            });
        });
    }

    // 全选列
    selectAll() {
        const columnConfig = CONFIG.COLUMN_CONFIG['AccessView'];
        this.currentColumns = Object.keys(columnConfig);
        this.generateColumnList();
    }

    // 全不选列
    deselectAll() {
        this.currentColumns = [];
        this.generateColumnList();
    }

    // 重置为默认配置
    resetToDefault() {
        this.currentColumns = [...CONFIG.DEFAULT_COLUMNS[this.currentTab]];
        this.generateColumnList();
    }

    // 清除所有保存的设置（用于调试）
    clearAllSettings() {
        this.savedSettings = {};
        this.saveSettings();
        // 重新加载当前列配置
        this.currentColumns = this.getCurrentColumns();
    }

    // 保存列设置
    saveColumnSettings() {
        this.saveCurrentColumns(this.currentColumns);
        this.closeSettings();
        
        // 触发表格重新渲染
        if (window.tableRenderer) {
            window.tableRenderer.updateColumns(this.currentColumns);
        }
    }
}

// 全局实例
window.columnSettings = new ColumnSettingsManager();

// 全局函数供HTML调用
function openColumnSettings() {
    const currentTab = document.querySelector('.tab.active').dataset.tab;
    window.columnSettings.openSettings(currentTab);
}

function closeColumnSettings() {
    window.columnSettings.closeSettings();
}

function selectAllColumns() {
    window.columnSettings.selectAll();
}

function deselectAllColumns() {
    window.columnSettings.deselectAll();
}

function resetToDefault() {
    window.columnSettings.resetToDefault();
}

function saveColumnSettings() {
    window.columnSettings.saveColumnSettings();
}