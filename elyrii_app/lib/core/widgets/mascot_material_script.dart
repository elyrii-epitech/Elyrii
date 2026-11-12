/// Public model-viewer APIs preserve the authored face while recoloring its
/// atlas. Three reusable canvas textures keep scrubbing memory bounded.
const mascotMaterialScript = r'''
if(!m.model)return;
m.elyriiDefaults=m.elyriiDefaults||new WeakMap();
m.elyriiTintCanvases=m.elyriiTintCanvases||{};
async function tinted(original,part,hex){
  if(!m.elyriiPalettePixels){
    m.elyriiPalettePixels=(async function(){
      var url=await original.source.createThumbnail(1024,1024);
      try{
        var image=new Image();image.src=url;await image.decode();
        var canvas=document.createElement('canvas');canvas.width=1024;canvas.height=1024;
        var context=canvas.getContext('2d',{willReadFrequently:true});
        context.translate(0,1024);context.scale(1,-1);
        context.drawImage(image,0,0);
        var data=context.getImageData(0,0,1024,1024);
        // Thumbnail render targets contain linear RGB; canvas textures are
        // sRGB. Convert once, before classifying the authored palette.
        for(var i=0;i<data.data.length;i+=4){
          for(var channel=0;channel<3;channel++){
            var v=data.data[i+channel]/255;
            data.data[i+channel]=255*(v<=0.0031308?12.92*v:1.055*Math.pow(v,1/2.4)-0.055);
          }
        }
        return data;
      }finally{URL.revokeObjectURL(url);}
    })();
  }
  var source=await m.elyriiPalettePixels;
  if(m.elyriiAppearanceRevision!==revision)return null;
  var target=m.elyriiTintCanvases[part];
  if(!target){
    var texture=m.createCanvasTexture();
    var canvas=texture.source.element;canvas.width=source.width;canvas.height=source.height;
    target=m.elyriiTintCanvases[part]={texture:texture,context:canvas.getContext('2d'),hex:null};
  }
  var key=(hex||'')+(part==='body'?'|'+(appearance.colors.details||'')+'|'+(appearance.colors.ears||''):'');
  if(target.hex!==key){
    var pixels=new Uint8ClampedArray(source.data);
    var rgb=hex?[1,3,5].map(function(i){return parseInt(hex.substring(i,i+2),16);}):null;
    var detail=appearance.colors.details;
    var detailRgb=detail?[1,3,5].map(function(i){return parseInt(detail.substring(i,i+2),16);}):null;
    var ears=appearance.colors.ears;
    var earRgb=ears?[1,3,5].map(function(i){return parseInt(ears.substring(i,i+2),16);}):null;
    for(var i=0;i<pixels.length;i+=4){
      var r=pixels[i],g=pixels[i+1],b=pixels[i+2];
      var max=Math.max(r,g,b),min=Math.min(r,g,b);
      var neutral=max>165&&(max-min)<28;
      var rosy=r>150&&r>g*1.18&&g>b*0.95;
      var mask=part==='body'?rgb&&r>110&&g/r>0.72&&b/g<0.94:
        part==='details'?max>165&&(max-min)<28:
        part==='eyes'?r>g*1.15&&b>g*1.15&&max<180:false;
      var selected=mask?rgb:part==='body'&&neutral?detailRgb:part==='body'&&rosy?earRgb:null;
      if(!selected)continue;
      var shade=part==='body'&&!neutral?Math.min(1.08,max/243):part==='eyes'?Math.min(1.2,max/80):max/255;
      for(var channel=0;channel<3;channel++)pixels[i+channel]=Math.min(255,selected[channel]*shade);
    }
    target.context.putImageData(new ImageData(pixels,source.width,source.height),0,0);
    target.texture.source.update();target.hex=key;
  }
  return target.texture;
}
for(const material of m.model.materials){
  await material.ensureLoaded();
  if(m.elyriiAppearanceRevision!==revision)return;
  var p=material.pbrMetallicRoughness;
  var original=m.elyriiDefaults.get(material);
  if(!original){
    original={color:p.baseColorFactor.slice(),texture:p.baseColorTexture.texture,
      roughness:p.roughnessFactor,metallic:p.metallicFactor,
      emissive:material.emissiveFactor.slice(),normal:material.normalTexture.texture};
    m.elyriiDefaults.set(material,original);
  }
  var name=material.name;
  var part=name==='root.2'||name==='Velours eyelids'?'body':
    name==='root.8'?'details':name==='root.10'?'eyes':
    name.startsWith('Velours accessory ')&&!/ (plum|gold|wood|core)$/.test(name)?'accessories':null;
  if(!part)continue;
  var color=appearance.colors[part];
  if(original.texture&&(color||(part==='body'&&(appearance.colors.details||appearance.colors.ears)))){
    var texture=await tinted(original.texture,part,color);
    if(m.elyriiAppearanceRevision!==revision)return;
    p.baseColorTexture.setTexture(texture);p.setBaseColorFactor(original.color);
  }else{
    p.baseColorTexture.setTexture(original.texture);
    p.setBaseColorFactor(color||original.color);
  }
  var glow=original.emissive;
  if(color&&part==='accessories'&&glow.some(function(v){return v>0;})){
    var strength=Math.max.apply(null,glow);
    glow=[1,3,5].map(function(i){
      var v=parseInt(color.substring(i,i+2),16)/255;
      return strength*(v<=0.04045?v/12.92:Math.pow((v+0.055)/1.055,2.4));
    });
  }else if(color&&part!=='accessories'){glow=[0,0,0];}
  material.setEmissiveFactor(glow);
  if(part==='body'||part==='details'){
    var finish=appearance.finish;
    p.setRoughnessFactor(finish==='satin'?0.38:finish==='porcelain'?0.18:original.roughness);
    p.setMetallicFactor(original.metallic);
    material.normalTexture.setTexture(finish==='velours'?original.normal:null);
    material.setClearcoatFactor(finish==='porcelain'?0.8:finish==='satin'?0.2:0);
    material.setClearcoatRoughnessFactor(0.12);
  }
}
''';
