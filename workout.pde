//7-minute workout program with customizeable workout and fancy google images
//if you're in processing 3.x, you'll need to go to sketch->import library->add library and add the 'minim' library before it will run
//if you're in processing 2.x, it should just run out of the box
//if you're human, you should ask Ben Fry and Casey Reas why they stopped including an audio library by default
import ddf.minim.*;
import java.net.HttpURLConnection;    // required for HTML download
import java.net.URL;                  // ditto, etc...
import java.net.URLConnection;
import java.net.URLEncoder;
import java.io.InputStreamReader;     // used to get our raw HTML source
import java.io.File;
PImage img=null;
String imageLink;
boolean DEBUG=false;  //print debug statements

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
  size(displayWidth, displayHeight);
  String lines[]=loadStrings("workout.txt");
  numberOfExercises=lines.length-1;
  println(numberOfExercises);
  exercises=new String[numberOfExercises];
  timings=new int[numberOfExercises];
  for (int i=1; i<lines.length; i++)
  {
    exercises[i-1]=split(lines[i], ',')[0];
    timings[i-1]=int(trim(split(lines[i], ',')[1]));
    println(exercises[i-1]+" "+timings[i-1]);
  }
  thread("updateImage");  //run this in a thread so we're not waiting around all day
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

  int imageWidth=width/4;
  int imageHeight=width/4;  
  if (img!=null)
  {
    imageHeight=(img.height/img.width)*imageWidth;
    image(img, 0, 0, imageWidth, imageHeight);
    image(img, width-imageWidth, 0, imageWidth, imageHeight);
    image(img, 0, height-imageHeight, imageWidth, imageHeight);
    image(img, width-imageWidth, height-imageHeight, imageWidth, imageHeight);
  }


  if (millis()/1000>seconds)  //run this every second to update the count
  {
    seconds++;
    count--;
    if (seconds%5==0)  //update the image every five seconds
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
      } else if (count<=3)
        click();
    } else if (mode=="period")
    {
      if (count==0)
      {
        mode="lead-in";
        count=leadIn; 
        completeExercises++;
        if (completeExercises<numberOfExercises) //get image of the next exercise
        {
          stopWhistle();
          thread("updateImage");
        }
      } else if (count<=3)
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
  int tries=0;
  int brightness=0;
  do {
    if (tries>0)
    {
      img = loadImage(imageLink, "jpeg");
      delay(250);
    }

    brightness=0;
    println("searching "+exercises[completeExercises]+" tries:  "+tries);
    img=randomGoogleImage(exercises[completeExercises]);
    try {
      img.updatePixels();
      for (int x=0; x<img.width; x+=img.width/5)
        for (int y=0; y<img.height; y+=img.height/5)        
          brightness+=brightness(img.pixels[y*img.width+x]);
    }
    catch(Exception e) {
    }
    println(img+" "+img.width+" "+img.height+" brightness: "+brightness);
    tries++;
  } while (((img==null)||(brightness==0))&&(tries<3));
}

//This code is based on Jeff Thompson's Google Image Search URL code, with some fixes for the
//html parsing.  
//Check out the original here:  https://github.com/jeffThompson/ProcessingTeachingSketches/tree/master/AdvancedTopics/GetGoogleImageSearchURLs
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
  if (DEBUG)
    println("Retreiving image links (" + fileSize + ")...\n");
  for (int search=0; search<numSearches; search++) {

    // let us know where we're at in the process
    if (DEBUG)
      print("  " + ((search+1)*20) + " / " + (numSearches*20) + ":");

    // get Google image search HTML source code; mostly built from PhyloWidget example:
    // http://code.google.com/p/phylowidget/source/browse/trunk/PhyloWidget/src/org/phylowidget/render/images/ImageSearcher.java
    if (DEBUG)
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
    if (DEBUG)
      println(" parsing...");
    if (source != null) {
      // built partially from: http://www.mkyong.com/regular-expressions/how-to-validate-image-file-extension-with-regular-expression
      String[][] m = matchAll(source, "<img[^>]+src\\s*=\\s*['\"]([^'\"]+)['\"][^>]*>");    // (?i) means case-insensitive
      if (m != null) {                                                                          // did we find a match?
        for (int i=0; i<m.length; i++) {                                                        // iterate all results of the match
          imageLinks = append(imageLinks, m[i][1]);                                             // add links to the array**
        }
      } else
        if (DEBUG)
          println("no match");
    }

    // ** here we get the 2nd item from each match - this is our 'group' containing just the file URL and extension

    // update offset by 20 (limit imposed by Google)
    offset += 20;
  }

  imageLink=imageLinks[(int)random(imageLinks.length)];

  // run in a 'try' in case we can't connect to an image
  try {
    img = loadImage(imageLink, "jpeg");
  }
  catch (Exception e) {
    println("    error downloading image, skipping...\n");    // likely a NullPointerException
  }

  return img;
}