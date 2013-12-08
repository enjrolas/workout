
import ddf.minim.*;
import java.net.HttpURLConnection;    // required for HTML download
import java.net.URL;                  // ditto, etc...
import java.net.URLConnection;
import java.net.URLEncoder;
import java.io.InputStreamReader;     // used to get our raw HTML source
import java.io.File;
PImage img=null;

int leadIn=7;
String[] exercises;
int[] timings;
int numberOfExercises;
PFont font;


Minim minim;
AudioPlayer click, startWhistle, endWhistle, stopWhistle;
int seconds=0;
int count=7;
int completeExercises=0;
String mode="lead-in";   //mode can be 'lead-in' or 'period' 

void setup()
{
  size(500, 500);
  String lines[]=loadStrings("workout.txt");
  numberOfExercises=lines.length;
  exercises=new String[numberOfExercises];
  timings=new int[numberOfExercises];
  for (int i=0;i<lines.length;i++)
  {
    exercises[i]=split(lines[i], ',')[0];
    timings[i]=int(trim(split(lines[i], ',')[1]));
    println(exercises[i]+" "+timings[i]);
  }
  thread("updateImage");
  font=loadFont("Kefa-Regular-48.vlw");
  // we pass this to Minim so that it can load files from the data directory
  minim = new Minim(this);

  click = minim.loadFile("click.mp3");
  startWhistle = minim.loadFile("startWhistle.mp3");
  stopWhistle = minim.loadFile("stopWhistle.mp3");
  endWhistle = minim.loadFile("end.mp3");
}

void draw()
{
  background(0);
  fill(255);
  if (mode=="lead-in")
    fill(1818, 234, 170);
  if (mode=="period")
    fill(88, 255, 254);
  if (count<=3)
    fill(255, 158, 54);
  if (mode=="lead-in")
    drawClock(count, leadIn);
  else
    drawClock(count, timings[completeExercises]);
  
  if(img!=null)
  {
    image(img, 0, 0);
    image(img, width-img.width, 0);
    image(img, 0, height-img.height);
    image(img, width-img.width, height-img.height);    
  }


  if (millis()/1000>seconds)  //run this every second to update the count
  {
    seconds++;
    count--;
    if(seconds%5==0)  //update the image every five seconds
        thread("updateImage");
    if (mode=="lead-in")
    {
      if (count==0)
      {
        if (completeExercises<numberOfExercises)
        {
          startWhistle();
          mode="period";
          count=timings[completeExercises];
        }
      }
        else if (count<=3)
          click();
    }
    else if (mode=="period")
    {
      if (count==0)
      {
        mode="lead-in";
        count=leadIn; 
        completeExercises++;
        if(completeExercises<numberOfExercises) //get image of the next exercise
        {
          stopWhistle();
          thread("updateImage");
        }
      }
      else if (count<=3)
        click();
    }
  }
  
  if (completeExercises==numberOfExercises)
  {
    endWhistle();
    delay(3000);  //give it enough time to finish playing the whistle before quitting -- otherwise it throws an error
    exit();
  }
}

void drawClock(int current, int max)
{
  float beginning=2*PI*current/max - PI/2;
  arc(width/2, height/2, 100, 100, -PI/2, beginning, PIE);
  textFont(font, 48);
  text(count, width/2-textWidth(""+count)/2, height/2-100);
  //make sure the name of the exercise isn't wider than the window, and if it is, scale the font down
  textFont(font, textWidth(exercises[completeExercises])>(width-50)?(float)48*((float)width-50.0)/(float)textWidth(exercises[completeExercises]):48);
  text(exercises[completeExercises], width/2-textWidth(exercises[completeExercises])/2, height/2+100);
}

void click()
{
  click.play();
  click.rewind();
}

void startWhistle()
{
  startWhistle.play();
  startWhistle.rewind();
}

void stopWhistle()
{
  stopWhistle.play();
  stopWhistle.rewind();
}

void endWhistle()
{
  endWhistle.play();
  endWhistle.rewind();
}

void updateImage()
{
  img=randomGoogleImage(exercises[completeExercises]);
}

PImage randomGoogleImage(String searchTerm)
{
int numSearches = 1;                 // how many searches to do (limited by Google to 20 images each) 
String fileSize = "10mp";             // specify file size in mexapixels - S/M/L not figured out yet :)
boolean saveImages = true;            // save the resulting images?

String source = null;                 // string to save raw HTML source code
String[] imageLinks = new String[0];  // array to save URLs to - written to file at the end
int offset = 0;                       // we can only 20 results at a time - increment to get total # of searches
int imgCount = 0;                     // count saved images for creating filenames
String outputTerm;
PImage img=null;

  // format spaces in URL to avoid problems; convert to _ for saving
  outputTerm = searchTerm.replaceAll(" ", "_");
  searchTerm = searchTerm.replaceAll(" ", "%20");

  // run search as many times as specified
  println("Retreiving image links (" + fileSize + ")...\n");
  for (int search=0; search<numSearches; search++) {
    
    // let us know where we're at in the process
    print("  " + ((search+1)*20) + " / " + (numSearches*20) + ":");

    // get Google image search HTML source code; mostly built from PhyloWidget example:
    // http://code.google.com/p/phylowidget/source/browse/trunk/PhyloWidget/src/org/phylowidget/render/images/ImageSearcher.java
    print(" downloading...");
    try {
      URL query = new URL("http://images.google.com/images?gbv=1&start=" + offset + "&q=" + searchTerm + "&tbs=isz:lt,islt:" + fileSize);
      HttpURLConnection urlc = (HttpURLConnection) query.openConnection();                                // start connection...
      urlc.setInstanceFollowRedirects(true);
      urlc.setRequestProperty("User-Agent", "");
      urlc.connect();
      BufferedReader in = new BufferedReader(new InputStreamReader(urlc.getInputStream()));               // stream in HTTP source to file
      StringBuffer response = new StringBuffer();
      char[] buffer = new char[1024];
      while (true) {
        int charsRead = in.read(buffer);
        if (charsRead == -1) {
          break;
        }
        response.append(buffer, 0, charsRead);
      }
      in.close();                                                                                         // close input stream (also closes network connection)
      source = response.toString();
    }
    // any problems connecting? let us know
    catch (Exception e) {
      e.printStackTrace();
    }

    // extract image URLs only, starting with 'imgurl'
    println(" parsing...");
    if (source != null) {
      // built partially from: http://www.mkyong.com/regular-expressions/how-to-validate-image-file-extension-with-regular-expression
      String[][] m = matchAll(source, "<img[^>]+src\\s*=\\s*['\"]([^'\"]+)['\"][^>]*>");    // (?i) means case-insensitive
      if (m != null) {                                                                          // did we find a match?
        for (int i=1; i<m.length; i++) {                                                        // iterate all results of the match
          imageLinks = append(imageLinks, m[i][1]);                                             // add links to the array**
        }
      }
      else
        println("no match");
    }

    // ** here we get the 2nd item from each match - this is our 'group' containing just the file URL and extension

    // update offset by 20 (limit imposed by Google)
    offset += 20;
  }

  // save the resulting URLs to a file (easier to see and save)
  println("\nWriting URLs to file...");
  saveStrings("urlLists/" + searchTerm + "_URLs.txt", imageLinks);

    String link=imageLinks[(int)random(imageLinks.length)];

      // run in a 'try' in case we can't connect to an image
      try {

        // get file's extension - format new filename for saving (use name with '_' instead of '%20'
        String extension = link.substring(link.lastIndexOf('.'), link.length()).toLowerCase();
        if (extension.equals("jpeg")) {        // normalize jpg extension
          extension = "jpg";
        }
        else if (extension.equals("tif")) {    // do the same for the unlikely case of a tiff file
          extension = "tiff";
        }
        String outputFilename = outputTerm + "_" + nf(imgCount, 5) + extension;
        println("  " + imgCount + ":\t" + outputFilename);

        // load and save!
        img = loadImage(link, "jpeg");
        img.save(sketchPath("") + outputTerm + "/" + outputFilename);
        imgCount++;
      }
      catch (Exception e) {
        println("    error downloading image, skipping...\n");    // likely a NullPointerException
      }
      
    return img;
}


