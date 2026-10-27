// Recover foreground colour and opacity from an image composited over white.
export function removeWhite(data,strength=1){
 for(let i=0;i<data.length;i+=4){
  const white=Math.min(data[i],data[i+1],data[i+2])*Math.min(1,Math.max(0,strength)),alpha=255-white;
  data[i+3]=Math.round(data[i+3]*alpha/255);
  if(alpha)for(let channel=0;channel<3;channel++)data[i+channel]=Math.round((data[i+channel]-white)*255/alpha);
 }
 return data;
}
