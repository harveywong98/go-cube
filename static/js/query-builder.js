/**
 * Query Builder - 表达式版本
 * 从 UI 收集过滤条件并构建查询参数
 */

class QueryBuilder {
  constructor() {
    this.defaults = {
      timeRange: CONFIG.TIME_RANGES['今天'],
    };
    this.timeRangeMap = CONFIG.TIME_RANGES;

    // 表达式字段映射到 Cube.js 字段名
    this.fieldMap = {
      ip: 'AccessView.ip',
      city: 'AccessView.ipGeoCity',
      uid: 'AccessView.uid',
      sid: 'AccessView.sid',
      host: 'AccessView.host',
      url: 'AccessView.url',
      method: 'AccessView.method',
      status: 'AccessView.status',
      result: 'AccessView.resultType',
      risk: 'AccessView.resultScore',
      rule: 'AccessView.resultRisk',
      asset: 'AccessView.assetName',
      sens: 'AccessView.sensScore',
      score: 'AccessView.sensScore',
      file: 'AccessView.fileName',
      size: 'AccessView.reqContentLength',
    };
  }

  /**
   * 解析表达式为 Cube.js filters
   * 支持: ip = '192.168' and (risk > 50 or result = '保护')
   */
  parseExpression(expr) {
    if (!expr || !expr.trim()) return [];

    const filters = [];
    const tokens = this.tokenize(expr);

    if (!tokens.length) return filters;

    // 简化的递归解析
    return this.parseOr(tokens);
  }

  tokenize(expr) {
    const tokens = [];
    const regex = /(\(|\)|and|or|[=<>!]+|contains|starts|ends|[\w\.]+|'[^']*'|"[^"]*"|\d+)/gi;
    let match;
    while ((match = regex.exec(expr)) !== null) {
      const token = match[0].toLowerCase().trim();
      if (token) tokens.push(token);
    }
    return tokens;
  }

  parseOr(tokens) {
    const parts = this.splitByOp(tokens, 'or');
    if (parts.length === 1) return this.parseAnd(parts[0]);

    // 多个 or 条件，用数组表示
    const orFilters = parts.map(p => this.parseAnd(p)).flat();
    return orFilters.length ? orFilters : [];
  }

  parseAnd(tokens) {
    const parts = this.splitByOp(tokens, 'and');
    return parts.map(p => this.parseCondition(p)).filter(Boolean);
  }

  splitByOp(tokens, op) {
    const parts = [];
    let current = [];
    let depth = 0;

    for (const token of tokens) {
      if (token === '(') depth++;
      if (token === ')') depth--;
      if (depth === 0 && token === op) {
        if (current.length) parts.push(current);
        current = [];
      } else {
        current.push(token);
      }
    }
    if (current.length) parts.push(current);
    return parts;
  }

  parseCondition(tokens) {
    // 去除括号
    while (tokens[0] === '(' && tokens[tokens.length - 1] === ')') {
      tokens = tokens.slice(1, -1);
    }
    if (tokens.length < 3) {
      console.warn('Condition parse failed: need at least 3 tokens, got', tokens);
      return null;
    }

    const field = tokens[0];
    const op = tokens[1];
    // 支持值包含多个token（如没有引号的空格），但通常值是一个token
    let value = tokens[2];
    // 如果有更多token且不是操作符，可能是值的一部分（但未引号包裹）
    if (tokens.length > 3) {
      // 尝试合并后续token直到遇到已知操作符或结束
      const stopWords = ['and', 'or'];
      let i = 3;
      while (i < tokens.length && !stopWords.includes(tokens[i]) && !this.fieldMap[tokens[i]]) {
        value += ' ' + tokens[i];
        i++;
      }
    }

    const cubeField = this.fieldMap[field];
    if (!cubeField) {
      console.warn('Unknown field:', field);
      return null;
    }

    const cleanValue = value.replace(/^['"]|['"]$/g, '');

    // 操作符映射
    const opMap = {
      '=': 'equals',
      '!=': 'notEquals',
      '>': 'gt',
      '>=': 'gte',
      '<': 'lt',
      '<=': 'lte',
      'contains': 'contains',
      'starts': 'startsWith',
      'ends': 'endsWith',
    };

    const result = {
      member: cubeField,
      operator: opMap[op] || 'equals',
      values: [cleanValue],
    };
    console.log('Parsed condition:', result);
    return result;
  }

  /**
   * 验证表达式语法并返回提示
   */
  validate(expr) {
    if (!expr || !expr.trim()) return { valid: true, hint: '输入表达式过滤，如: ip contains "192.168" 或 ip != "10.0.0.1"', filters: [] };

    const tokens = this.tokenize(expr);
    if (!tokens.length) return { valid: false, hint: '❌ 无效的表达式', filters: [] };

    try {
      const filters = this.parseExpression(expr);
      console.log('Validate tokens:', tokens, 'filters:', filters);

      // 检查无效字段和操作符
      for (let i = 0; i < tokens.length; i++) {
        const t = tokens[i];
        // 检查是否为字段名（小写字母）
        if (/^[a-z]+$/.test(t)) {
          if (!this.fieldMap[t] && !['and', 'or', 'contains', 'starts', 'ends'].includes(t)) {
            return { valid: false, hint: `❌ 未知字段: "${t}"，可用字段: ${Object.keys(this.fieldMap).slice(0, 10).join(', ')}...`, filters: [] };
          }
        }
        // 检查字段后的操作符
        if (i > 0 && /^[a-z]+$/.test(tokens[i-1]) && this.fieldMap[tokens[i-1]]) {
          const prevToken = tokens[i-1];
          const op = t;
          const validOps = ['=', '!=', '>', '>=', '<', '<=', 'contains', 'starts', 'ends'];
          if (!validOps.includes(op) && !['and', 'or'].includes(op)) {
            return { valid: false, hint: `❌ 字段 "${prevToken}" 后的 "${op}" 不是有效操作符。可用: =, !=, >, >=, <, <=, contains, starts, ends`, filters: [] };
          }
        }
      }

      if (filters.length === 0) {
        // 分析为什么解析失败
        if (tokens.length >= 1 && this.fieldMap[tokens[0]]) {
          if (tokens.length === 1) {
            return { valid: false, hint: `❌ 字段 "${tokens[0]}" 后缺少操作符和值，例如: ${tokens[0]} = 'value'`, filters: [] };
          }
          if (tokens.length === 2) {
            return { valid: false, hint: `❌ 操作符 "${tokens[1]}" 后缺少值，例如: ${tokens[0]} ${tokens[1]} 'value'`, filters: [] };
          }
        }
        return { valid: false, hint: '❌ 无法解析表达式，格式: 字段 操作符 值，例如: ip = "192.168.1.1"', filters: [] };
      }

      // 显示解析后的条件详情
      const filterDesc = filters.map(f => {
        const shortField = Object.keys(this.fieldMap).find(k => this.fieldMap[k] === f.member) || f.member;
        return `${shortField} ${f.operator} "${f.values[0]}"`;
      }).join(' AND ');

      return { valid: true, hint: `✓ ${filterDesc}`, filters };
    } catch (e) {
      console.error('Validate error:', e);
      return { valid: false, hint: '❌ 语法错误: ' + e.message, filters: [] };
    }
  }

  build(viewType = 'access') {
    const expr = document.querySelector('#filter-expr')?.value || '';
    const timeSelect = document.querySelector('#time-range-select');
    const limitInput = document.querySelector('#limit-input');

    const filters = this.parseExpression(expr);

    // 根据视图类型添加默认过滤
    if (viewType === 'sensitive') {
      // 敏感数据tab：默认只显示有敏感数据的（sensScore > 0）
      filters.push({
        member: 'AccessView.sensScore',
        operator: 'gt',
        values: ['0']
      });
    } else if (viewType === 'file') {
      // 文件传输tab：默认只显示有文件名的（使用 notEquals 空字符串）
      filters.push({
        member: 'AccessView.fileName',
        operator: 'notEquals',
        values: ['']
      });
    }

    return {
      timeRange: this.timeRangeMap[timeSelect?.value] || this.defaults.timeRange,
      limit: parseInt(limitInput?.value) || 100,
      filters,
      expression: expr,
    };
  }

  reset() {
    const expr = document.querySelector('#filter-expr');
    const timeSelect = document.querySelector('#time-range-select');
    const limitInput = document.querySelector('#limit-input');

    if (expr) expr.value = '';
    if (timeSelect) timeSelect.value = '今天';
    if (limitInput) limitInput.value = '50';

    this.updateHint('');
  }

  updateHint(expr) {
    const hint = document.querySelector('#expr-hint');
    const debug = document.querySelector('#expr-debug');
    if (!hint) return;

    const result = this.validate(expr);
    hint.textContent = result.hint;
    hint.className = `mt-2 text-[10px] ${result.valid ? 'text-green-400' : 'text-red-400'}`;

    // 显示解析后的 filter 详情
    if (debug && result.filters && result.filters.length > 0) {
      const filterJson = JSON.stringify(result.filters, null, 0).substring(0, 100);
      debug.textContent = filterJson.length > 100 ? filterJson + '...' : filterJson;
    } else if (debug) {
      debug.textContent = '';
    }

    // 存储供调试用
    if (result.filters) {
      this.lastParsedFilters = result.filters;
    }
  }
}

// 导出供其他模块使用
if (typeof module !== 'undefined' && module.exports) {
  module.exports = QueryBuilder;
}
