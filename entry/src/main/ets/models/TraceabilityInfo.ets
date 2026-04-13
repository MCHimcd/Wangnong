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
