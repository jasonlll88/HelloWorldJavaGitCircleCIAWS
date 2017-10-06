package main.java;

import java.util.concurrent.TimeUnit;

public class HelloWorldGitCircleCIAWS {

	public static void main(String[] args) throws InterruptedException {

	
		while (true) {
		System.out.println("Hello World java with github, circleci and aws");
		System.out.println("This has been a change to test the code until circleci");
		TimeUnit.SECONDS.sleep(1);
		
		}
	}
}
