import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import ddf.minim.*; 
import java.net.HttpURLConnection; 
import java.net.URL; 
import java.net.URLConnection; 
import java.net.URLEncoder; 
import java.io.InputStreamReader; 
import java.io.File; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class workout extends PApplet {



    // required for HTML download
                  // ditto, etc...


     // used to get our raw HTML source

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

public void setup()
{
  size(500, 500);
  String lines[]=loadStrings("workout.txt");
  numberOfExercises=lines.length-1;
  println(numberOfExercises);
  exercises=new String[numberOfExercises];
  timings=new int[numberOfExercises];
  for (int i=1;i<lines.length;i++)
  {
    exercises[i-1]=split(lines[i], ',')[0];
    timings[i-1]=PApplet.parseInt(trim(split(lines[i], ',')[1]));
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

public void draw()
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

  if (img!=null)
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
        if (completeExercises<numberOfExercises) //get image of the next exercise
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

public void drawClock(int current, int max)
{
  float beginning=2*PI*current/max - PI/2;
  arc(width/2, height/2, 100, 100, -PI/2, beginning, PIE);
  textFont(font, 48);
  text(count, width/2-textWidth(""+count)/2, height/2-100);
  //make sure the name of the exercise isn't wider than the window, and if it is, scale the font down
  textFont(font, textWidth(exercises[completeExercises])>(width-50)?(float)48*((float)width-50.0f)/(float)textWidth(exercises[completeExercises]):48);
  text(exercises[completeExercises], width/2-textWidth(exercises[completeExercises])/2, height/2+100);
}

public void click()
{
  click.play();
  click.rewind();
}

public void startWhistle()
{
  startWhistle.play();
  startWhistle.rewind();
}

public void stopWhistle()
{
  stopWhistle.play();
  stopWhistle.rewind();
}

public void endWhistle()
{
  endWhistle.play();
  endWhistle.rewind();
}

public void updateImage()
{
  img=randomGoogleImage(exercises[completeExercises]);
}

//This code is based on Jeff Thompson's Google Image Search URL code, with some fixes for the
//html parsing.  
//Check out the original here:  https://github.com/jeffThompson/ProcessingTeachingSketches/tree/master/AdvancedTopics/GetGoogleImageSearchURLs
public PImage randomGoogleImage(String searchTerm)
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
        for (int i=0; i<m.length; i++) {                                                        // iterate all results of the match
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

  String link=imageLinks[(int)random(imageLinks.length)];

  // run in a 'try' in case we can't connect to an image
  try {
    img = loadImage(link, "jpeg");
  }
  catch (Exception e) {
    println("    error downloading image, skipping...\n");    // likely a NullPointerException
  }

  return img;
}

  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "--full-screen", "--bgcolor=#666666", "--stop-color=#cccccc", "workout" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
