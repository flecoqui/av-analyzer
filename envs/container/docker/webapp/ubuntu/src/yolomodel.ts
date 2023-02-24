// Yolov3 Inference Model
export class Box {
    l: number = 0;
    t: number = 0;
    w: number = 0;
    h: number = 0;
}
export class DetectedObject {
    value: string = "";
    confidence: number = 0;
}  
export class Tag {
    tag: DetectedObject =  { value: "", confidence: 0} ;
    box: Box = {l:0,t:0,w:0,h:0};
}  
export class Entity {
    type: string = "";
    entity: Tag = { tag: { value: "", confidence: 0}, box: {l:0,t:0,w:0,h:0}} ;
}  
export class YoloInferences {
    inferences: Entity[] = [];
}  
