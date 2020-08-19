//This script has been created using the Macro language of ImageJ
//The input for this script is a folder containing multistack (i.e. z-stacked) greyscale images containing pollen grains
//The output of this script are three projections for each pollen grain identified, Standard Deviation, Minimum Intensity and Extended Focus (R) Richard Wheeler (http://www.richardwheeler.net/contentpages/text.php?gallery=ImageJ_Macros&file=Extended_Depth_of_Field&type=ijm)

input = getDirectory("Choose Input Directory");
output = getDirectory("Choose Output Directory");

list = getFileList(input);
setBatchMode(false);

Dialog.create("Z-stack");
Dialog.addMessage("Please fill in the amount of Z-stack focus levels for your raw images");
Dialog.addNumber("Focus levels:", 20);
Dialog.show();
focuslevels = Dialog.getNumber();
print("Z-stack focus levels:", focuslevels);

//First we load the images from the stack and use Analyze Particles to find the pollen grains
for (i = 1; i < list.length; i=i+focuslevels) {
	print("Current image: " + list[i]);
	run("Image Sequence...", "open=["+input+"] number=["+focuslevels+"] starting=["+i+"] increment=1");
	run("8-bit");
	mainTitle=getTitle(); 
	selectWindow(mainTitle);
	run("Z Project...", "projection=[Min Intensity]");
	setOption("BlackBackground", false);
	run("Make Binary");
	run("Fill Holes");
	run("Watershed");	
    run("Analyze Particles...", "size=0.49-22 circularity=0.20-1.00 exclude include add");    
    selectWindow(mainTitle);
    
    for (u=0; u < roiManager("count"); ++u) {
    	roiManager("Select", u);
    	run("Duplicate...", "title=crop.tif duplicate");
		print( "Working on ROI index: " + roiManager("index"));
		
		//Using a threshold we remove slices that are out of focus
		Stack.getDimensions(width,height,channels,slices,frames);
		s = 1;
		for (s = 1; s <= slices; s++) {
		setSlice(s);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		if (min > 126 || max < 152) {
			run("Delete Slice");
			Stack.getDimensions(width,height,channels,slices,frames);
	    	}
		}
		
		//Then we make three projections of the pollen grain stack: Standard Deviation, Minimum Intensity and Extended Focus		
		run("Z Project...", "projection=[Standard Deviation]");
		run("8-bit");
		rename("proj_stdv");
		selectWindow("crop.tif");
		run("Z Project...", "projection=[Min Intensity]");
		rename("proj_min");
		selectWindow("crop.tif");

		//The following code creates the Extended Focus projection using Extended_Depth_of_Field plugin of Richard Wheeler 
		//(please see https://www.richardwheeler.net/contentpages/text.php?gallery=ImageJ_Macros&file=Extended_Depth_of_Field&type=ijm)
		//User variables
		radius=3;
	
		//Get start image properties
		w=getWidth();
		h=getHeight();
		d=nSlices();
		source=getImageID();
		origtitle=getTitle();
		//rename("tempnameforprocessing");
		//sourcetitle=getTitle();
		//setBatchMode(true);
	
		//Generate edge-detected image for detecting focus
		run("Duplicate...", "title=["+origtitle+"_Heightmap] duplicate range=1-"+d);
		
		heightmap=getImageID();
		heightmaptitle=getTitle();
		run("Find Edges", "stack");
		run("Maximum...", "radius="+radius+" stack");
	
		//Alter edge detected image to desired structure
		run("32-bit");
		for (x=0; x<w; x++) {
		    showStatus("Finding Z depths");
		    showProgress(x/w);
	    	for (y=0; y<h; y++) {
	        	slice=0;
	        	max=0;
	        	for (z=0; z<d; z++) {
	            	setZCoordinate(z);
	            	v=getPixel(x,y);
	           	 	if (v>=max) {
	               	 	max=v;
	                	slice=z;
	           	 	}
	        	}
	        	for (z=0; z<d; z++) {
	           	 setZCoordinate(z);
	            	if (z==slice) {
	                	setPixel(x,y,1);
	            	} else {
	                	setPixel(x,y,0);
	            	}
	        	}
	   	 	}
		}
		run("Gaussian Blur...", "sigma="+radius+" stack");
	
		//Generation of the final image
		setBatchMode(false);
		//Multiply modified edge detect (the depth map) with the source image		
		run("Image Calculator...", "image1="+origtitle+" operation=Multiply image2="+heightmaptitle+" create 32-bit stack");
		multiplication=getImageID();
		//Z project the multiplication result
		run("Z Project...", "start=1 stop="+d+" projection=[Sum Slices]");
		run("8-bit");
		rename("proj_ext");
		run("Images to Stack", "name=["+mainTitle+"] title=[proj] use");
		rename("proj_total");
		//Some tidying
		//rename(origtitle+"_focused");
		selectImage(heightmap);
		close();
		selectImage(multiplication);
		close();
		selectImage(source);
		rename(origtitle);
		setBatchMode(false);
		selectWindow(mainTitle);
		//print(mainTitle);
		selectImage("proj_total");
		dir=File.nameWithoutExtension;
		name=substring(dir,0,indexOf(dir,"_Z"));
		saveAs("Tiff",output + name + "_"+u+"_STD-MIN-EF");
        close();
        close("crop.tif");
        print("Moving to next ROI");
        }
        run("Close All");
        if (roiManager("count") > 0){
        	roiManager("Deselect");
        	roiManager("Delete");
        }
        print("NEXT IMAGE");  
}
run("Close All");
print("FINISHED");
