// <GUI menuname="Process LCMS (batch)" shortcut="Ctrl+2" tooltip="Select parent directory containing raw+export folders and masses.csv file at root" icon="C:/bin2.jpg" />
function processLCMSbatch()
{
  /*
    This script uses local peak detection settings for the quantification channel (ELSD) and the MS EIC channel.
    Recommended settings (JSON):
    {
      "objectName": "MSChromPeakDetectionSettings",
      "smoothWindowSize": 0,
      "sensitivity": 55,
      "shoulderSensitivity": 0.1,
      "widePeaks": false,
      "minAreaThreshold": 0.0005,
      "exclusionRegions": {
          "objectName": "MSChromPeakDetectionExcludingRegs",
          "units": "Time",
          "upToEnabled": true,
          "afterEnabled": false,
          "upTo": 1,
          "after": 1000,
          "__historyItem": {}
      },
      "maximumWidth": {
          "objectName": "MSChromPeakDetectionMaxWidth",
          "enabled": true,
          "units": "Time",
          "threshold": 0.5,
          "__historyItem": {}
      },
      "__historyItem": {}
    }
    Parent directory should contain "raw" (contains .D chromatogram files) and "export" folders. The raw folder should contain .D files. The root folder should contain a masses.csv file with the following format:
    Data file name,Display name,Mass1(used for tracking quantified peak in quantification channel),Mass2,Mass3
  */
  const dirName  = FileDialog.getExistingDirectory(Dir.current(), "Select parent directory containing raw+export folders");
  const quantMSdelay = 0.113; // delay in minutes between quantification and MS channels (positive value means MS channel is early relative to quantification channel)
  const tolerance = 0.25; // mass tolerance in Da +/-
  const voidVolumeExclude = 1; // limit in minutes to exclude peaks before this RT (void volume)
  const chromatogramScaleSpaceAbove = 1.2; // space above the highest peak in the quantification channel (higher, to render peak labels)
  const chromatogramScaleSpaceBelow = 0.6; // space below the baseline the quantification channel
  const rawPathDir = dirName + "\\raw";
  const exportPathDir = dirName + "\\export";
  const exportPathTable = exportPathDir + "\\results.csv";
  const massesCSV = dirName + "\\masses.csv";
  var dir = new Dir(rawPathDir);
  if (!dir.exists)
  {
    return;
  }
  var files = dir.entryList("*.D",Dir.Dirs,Dir.Name);
  if (files.length == 0)
  {
    MessageBox.critical("No .D files found in " + rawPathDir,MessageBox.Ok);
    return;
  }
  // clear export table and write header
  var exportTable = new File(exportPathTable);
  exportTable.open(File.WriteOnly);
  TextStream(exportTable).write("Display name," +
    "Data file," +
    "Largest peak area (per MS)," +
    "Peak area sum," +
    "Target % (per MS)," +
    "Lax peak areas (per MS)," +
    "Target lax % (per MS)," +
    "Isomer peak areas," +
    "Isomer %," +
    "Largest peak area (per quant)," +
    "Target % (per quant)," +
    "Largest peak area (MS EIC)," +
    "Largest peak area % (MS EIC)," +
    "RT (per MS)," +
    "RT (per quant)," +
    "m/z lower bound," +
    "m/z upper bound\r\n");
  exportTable.close(); 
  // create progress window
  var progressWindow = new ProgressDialog();
  progressWindow.labelText = "Processing LCMS batch (1/" + files.length + ")                         ";
  progressWindow.maximum = files.length;
  progressWindow.minimum = 0;
  progressWindow.value = 0;
  progressWindow.minimumDuration = 0;
  progressWindow.showCancelButton = true;
  const startTimestamp = Date.now();
  // loop over all .D files in the raw folder
  for(var k = 0; k < files.length; k++)
  {
    var dw = new DocumentWindow(Application.mainWindow.newWindow());
    if (serialization.open(rawPathDir + "\\" + files[k]))
    {
      var msItem = mass.activeItem();
      if( msItem != undefined ) 
      {
        const dataFileName = msItem.datasetFileName.split("\\")[msItem.datasetFileName.split("\\").length-1];
        var massFound = false;
        var massTable = new File(massesCSV);
        massTable.open(File.ReadOnly);
        var massTst = TextStream(massTable);
        var lines = massTst.readAll().split("\r\n");
        for (var i=0; i<lines.length; i++)
        {
          if (lines[i].split(",")[0] == dataFileName) 
          { 
            msTargetRange1 = [{"from": Number(lines[i].split(",")[2])-tolerance, "to": Number(lines[i].split(",")[2])+tolerance}];
            msTargetRange2 = [{"from": Number(lines[i].split(",")[3])-tolerance, "to": Number(lines[i].split(",")[3])+tolerance}];
            msTargetRange3 = [{"from": Number(lines[i].split(",")[4])-tolerance, "to": Number(lines[i].split(",")[4])+tolerance}];
            displayName = lines[i].split(",")[1];
            exportPath = exportPathDir + "\\" + displayName + " "+ files[k] + ".pdf";  
            massFound = true;
          }
        } 
        if(!massFound) 
        {
          MessageBox.information("Mass not found\nData file name: " + dataFileName + "\nCSV file: " + massesCSV);
          return;
        }
        massTable.close();
        // remove PDA + TIC chromatograms from the layout (default for my .D files)
        msItem.hidePlot(0);
        msItem.hidePlot(1);
        // add chromatogram used for quantification, e.g. ELSD
        var parmQuant = new Object();
        parmQuant.injectionIndex = 0;
        parmQuant.traceIndex = 5; // ELSD Signal, other options: 1 for "VWD1" channel (instrument dependent)
        parmQuant.type = 1; // valid value for ELSD Signal, other options: "UV" for UV channel
        msItem.newChromatogram(parmQuant);
        // add EIC MS chromatogram used for selecting target peak in quantification chromatogram
        var parmMS1 = new Object();
        parmMS1.injectionIndex = 0;
        parmMS1.functionIndex = 0;
        parmMS1.type = "Mass";
        parmMS1.mass_ranges = msTargetRange1;
        msItem.newChromatogram(parmMS1);
        // ancillary EIC MS chromatograms (not used for quantification or peak selection)
        var parmMS2 = new Object();
        parmMS2.injectionIndex = 0;
        parmMS2.functionIndex = 0;
        parmMS2.type = "Mass";
        parmMS2.mass_ranges = msTargetRange2;
        msItem.newChromatogram(parmMS2);
        var parmMS3 = new Object();
        parmMS3.injectionIndex = 0;
        parmMS3.functionIndex = 0;
        parmMS3.type = "Mass";
        parmMS3.mass_ranges = msTargetRange3;
        msItem.newChromatogram(parmMS3);
        // parameters of the largest peak in MS EIC channel parameters
        var maxAreaMS = 0;
        var maxRTMS = 0;
        var startMS = 0;
        var endMS = 0;
        var maxIndexMS = 0;
        var sumAreaMS = 0;
        var isomerAreaSumQuant = 0; // sum of areas of all isomer peaks in the quantification channel
        var peaksMatchedIndecesQuant = []; // indeces of all isomer peaks in the quantification channel
        var maxPerQuantRT = 0; // RT of the largest peak in the quantification channel within the region of any peak in the MS EIC channel (less reliable)
        var maxPerQuantArea = 0; // area of the largest peak in the quantification channel within the region of any peak in the MS EIC channel (less reliable)
        var maxPerQuantIndexQuant = 0; // index of the largest peak in the quantification channel within the region of any peak in the MS EIC channel (less reliable)
        var maxPerQuantIndexMS = 0; // index of the peak in the MS EIC channel corresponding to the largest peak in the quantification channel (less reliable)
        var peakHeightHighestQuant = 0; // height of the lowest peak in the quantification channel 
        for (var i=0; i<msItem.plot(4).peaks.length; i++) // loop over MS peaks
        {
          for (var j=0; j<msItem.plot(3).peaks.length; j++) // loop over quantification channel peaks - this serves the purpose to find all isomer peaks in the quantification channel which have a corresponding peak in the MS EIC channel
          {
            if(msItem.plot(3).peaks[j].height > peakHeightHighestQuant) 
            {
              peakHeightHighestQuant = msItem.plot(3).peaks[j].height;
            }
            if (msItem.plot(3).peaks[j].center.x > (msItem.plot(4).peaks[i].start.x+quantMSdelay) && msItem.plot(3).peaks[j].center.x < (msItem.plot(4).peaks[i].end.x+quantMSdelay)) 
            {
              if(peaksMatchedIndecesQuant.indexOf(j)==-1) 
              {
                peaksMatchedIndecesQuant.push(j);
                isomerAreaSumQuant = isomerAreaSumQuant + msItem.plot(3).peaks[j].area;
                if(msItem.plot(3).peaks[j].area > maxPerQuantArea) 
                { 
                  // find the largest peak in the quantification channel within the region of any peak in the MS EIC channel (less reliable) 
                  maxPerQuantArea = msItem.plot(3).peaks[j].area; 
                  maxPerQuantRT = msItem.plot(3).peaks[j].center.x; 
                  maxPerQuantIndexQuant = j;
                  maxPerQuantIndexMS = i;
                }
              }
            }
          }
          if (msItem.plot(4).peaks[i].center.x > voidVolumeExclude) 
          {
            sumAreaMS = sumAreaMS + msItem.plot(4).peaks[i].area;
          }
          if (msItem.plot(4).peaks[i].area > maxAreaMS) 
          { 
            maxAreaMS = msItem.plot(4).peaks[i].area; // useful to check this value in output, so that we see that we did not identify the largest peak in quantification channel based on just MS noise
            maxRTMS = msItem.plot(4).peaks[i].center.x; 
            startMS = msItem.plot(4).peaks[i].start.x;
            endMS = msItem.plot(4).peaks[i].end.x;
            maxIndexMS = i; 
          }
        }
        msItem.plot(3).setPeakFillColor(maxPerQuantIndexQuant,"#ffffff00"); // highlight the largest peak in quantification channel within the region of any peak in MS EIC channel (less reliable)
        msItem.plot(4).setPeakFillColor(maxPerQuantIndexMS,"#ffffff00"); // highlight the peak in MS EIC channel corresponding to large the largest peak in the quantification channel (less reliable)
        msItem.plot(4).setPeakFillColor(maxIndexMS,"#ff00ff00"); // highlight the largest peak in MS EIC channel
        var sumAreaTotalQuant = 0; // sum of all peaks in the quantification channel excluding void volume
        var maxPerMSIndexQuant = 0;  // index of the largest peak in the quantification channel within the region of the largest peak in MS EIC channel
        var maxPerMSArea = 0; // area of the largest peak in the quantification channel within the region of the largest peak in MS EIC channel
        var maxPerMSAreaLax = 0; // area of all the peaks in the quantification channel within the region of the largest peak in MS EIC channel
        var arrayExcluded = [];
        for (var i=0; i<msItem.plot(3).peaks.length; i++) 
        {
          if (msItem.plot(3).peaks[i].center.x > (startMS+quantMSdelay) && msItem.plot(3).peaks[i].center.x < (endMS+quantMSdelay)) 
          {
            maxPerMSAreaLax = maxPerMSAreaLax + msItem.plot(3).peaks[i].area;
            if(msItem.plot(3).peaks[i].area > maxPerMSArea) 
            {
              maxPerMSArea = msItem.plot(3).peaks[i].area;
              maxPerMSIndexQuant = i;     
            }
          }
          // exclude peaks in void volume from sum that will be used for Target % calculation
          if (msItem.plot(3).peaks[i].center.x < voidVolumeExclude) 
          {
            arrayExcluded.push(i);
          }
          else 
          {
            sumAreaTotalQuant = sumAreaTotalQuant + msItem.plot(3).peaks[i].area;
          }
        }
        msItem.plot(3).setPeakFillColor(maxPerMSIndexQuant,"#ff00ff00"); // highlight the largest peak in quantification channel within the region of the largest peak in MS EIC channel
        // Remove peaks in void volume in displayed layout
        for (var i = 0; i < arrayExcluded.length; i++) {
          msItem.plot(3).removePeak(0);
        }
        // scale the quantification channel to the highest peak
        var baseline = msItem.plot(3).dataPoints[0].y; // baseline of the quantification channel
        var range = {from: baseline - Math.abs(peakHeightHighestQuant - baseline) * chromatogramScaleSpaceBelow, to: baseline + peakHeightHighestQuant + Math.abs(peakHeightHighestQuant - baseline) * chromatogramScaleSpaceAbove}; // range of the quantification channel
        msItem.plot(3).zoom("vertical",range);
        // move quantification channel to the top
        msItem.selectSpectra(msItem.plot(4), maxRTMS);
        msItem.movePlot(2, 4);    
        // refresh the displayed layout
        msItem.update(); 
        mainWindow.activeWindow().update();
        // export the layout to PDF
        mainWindow.activeDocument.exportToPDF(exportPath, mainWindow.activeDocument.curPage());
        // append results to the export table
        var exportTable = new File(exportPathTable);
        exportTable.open(File.Append);
        TextStream(exportTable).write(
          displayName + "," +
          dataFileName + "," +
          maxPerMSArea + "," +
          sumAreaTotalQuant + "," +
          ((maxPerMSArea/sumAreaTotalQuant)*100) + "," +
          maxPerMSAreaLax + "," +
          ((maxPerMSAreaLax/sumAreaTotalQuant)*100) + "," +
          isomerAreaSumQuant + "," +
          ((isomerAreaSumQuant/sumAreaTotalQuant)*100) + "," +
          maxPerQuantArea + "," +
          ((maxPerQuantArea/sumAreaTotalQuant)*100) + "," +
          maxAreaMS + "," +
          ((maxAreaMS/sumAreaMS)*100) + "," +
          maxRTMS + "," +
          maxPerQuantRT + "," +
          msTargetRange1[0].from + "," +
          msTargetRange1[0].to + "\r\n"
        );
        exportTable.close();
      }
      // save the layout to .mnova file
      serialization.save(exportPathDir + "\\" + displayName + " "+ files[k] +".mnova", "mnova");
    }
    dw.close();
    // update progress window and check if it was canceled
    progressWindow.value = k+1;
    progressWindow.labelText = "Processing LCMS batch (" + (k+1) + "/" + files.length + ") ETA: " + new Date((Date.now()-startTimestamp)/(k+1)*(files.length-k-1)).toISOString().slice(11, 19);
    if(progressWindow.wasCanceled) break;
  }
}

