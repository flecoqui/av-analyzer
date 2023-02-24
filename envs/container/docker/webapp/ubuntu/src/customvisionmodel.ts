// Custom Vision Inference Model
/*
{"id":"f11e771e-b3d1-4aa1-91f9-1ae5b5ea1ff4",
"project":"5d2fb5c1-8273-49b0-8dee-c39b40a6f876",
"iteration":"193cd765-a89c-43a9-9e45-b7705f0841c8",
"created":"2022-10-04T16:54:54.363Z",
"predictions":
[
{"probability":0.061713934,"tagId":"08e08234-cda3-42dd-b036-d22d5853f773","tagName":"ladder","boundingBox":{"left":0.13520098,"top":0.027334869,"width":0.74326086,"height":0.9151208}},
{"probability":0.0121720135,
"tagId":"08e08234-cda3-42dd-b036-d22d5853f773",
"tagName":"ladder",
"boundingBox":{"left":0.2800629,"top":-0.09190044,"width":0.46480322,"height":0.8521081}
}
]
}
*/

export class BoundingBox {
    left: number = 0;
    top: number = 0;
    width: number = 0;
    height: number = 0;
}  
export class Prediction {
    probability: number = 0;
    tagId: string = "";
    tagName: string = "";
    boundingBox: BoundingBox = { left: 0, top: 0, width: 0, height: 0} ;
}  
export class CustomVisionInferences {
    id: string ="";
    project: string ="";
    iteration: string ="";
    created: string ="";

    predictions: Prediction[] = [];
}  

