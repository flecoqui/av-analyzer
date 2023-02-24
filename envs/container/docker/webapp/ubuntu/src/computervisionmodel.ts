// Computer Vision Inference Model

export class Metadata {
    height: number = 0;
    width: number = 0;
    format: string = ""
}  
export class Box {
    x: number = 0;
    y: number = 0;
    w: number = 0;
    h: number = 0;
}  
export class Object {
    rectangle: Box = {x:0,y:0,w:0,h:0};
    object: string = "";
    confidence: number = 0;
}  
export class Tag {
    name: string = "";
    confidence: number = 0;
}  
export class Detail {
    landmarks = [] ;
}  
export class Category {
    name: string = "";
    score: number = 0;
    detail: Detail = { landmarks: []} ;
}  
export class ComputerVisionInferences {
    categories: Category[] = [];
    tags: Tag[] = [];
    objects: Object[] = [];
    requestId: string ="";
    metadata: Metadata = { height: 0, width: 0, format: ""};
    modelVersion: string = "";
}  

