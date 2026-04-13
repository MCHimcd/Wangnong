/**
 * Purpose: 定义溯源查询结果及页面跳转参数的数据结构。
 * Responsibilities: 承载产品基础信息、质检信息、流转步骤，以及详情页导航所需的序列化字段。
 * Flow: TraceabilityScanPage 获取后端结果后组装 TraceabilityInfo，并通过 TraceabilityDetailNavParams 传给详情页。
 * Dependencies: 被溯源扫描页、详情页和 HttpService 共用。
 * Input: 后端返回的溯源详情数据。
 * Output: 可被详情页直接渲染的结构化对象。
 */
export class TraceabilityStepInfo {
  stepName: string = '';
  operator: string = '';
  time: string = '';
  location: string = '';
  remark: string = '';
}

export class TraceabilityInfo {
  productName: string = '';
  batchCode: string = '';
  variety: string = '';
  origin: string = '';
  farmName: string = '';
  plotId: string = '';
  plantDate: string = '';
  harvestDate: string = '';
  shelfLife: string = '';
  qualityGrade: string = '';
  certNo: string = '';
  inspectorName: string = '';
  inspectDate: string = '';
  steps: TraceabilityStepInfo[] = [];
}

export class TraceabilityDetailNavParams {
  infoJson: string = '';
}
