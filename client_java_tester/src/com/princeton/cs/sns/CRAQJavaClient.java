package com.princeton.cs.sns;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.net.Socket;

public class CRAQJavaClient {

	private static void printUsage() {
		System.err.println("Usage: java com.princeton.cs.sns.CRAQJavaClient host port key");
		System.exit(1);
	}
	
	public static void main(String[] args) {
		if(args.length != 3) {
			printUsage();
		}
		
		String hostname = args[0];
		int port = 0;
		
		try {
			port = Integer.parseInt(args[1]);
		} catch(NumberFormatException e) {
			printUsage();
		}
		
		String keyName = args[2];
		
		try {
			Socket s = new Socket(hostname, port);
			BufferedWriter bufOut = new BufferedWriter(new OutputStreamWriter(s.getOutputStream()));
			BufferedReader bufIn = new BufferedReader(new InputStreamReader(s.getInputStream()));
			
			long begin = System.currentTimeMillis();
			long num_did = 0;
			while(System.currentTimeMillis() < begin + 10000) {
				bufOut.write("get " + keyName + "\r\n");
				bufOut.flush();
				String line = bufIn.readLine();
				String line2 = bufIn.readLine();
				num_did++;
			}
			System.out.println(num_did / 10.0);
		} catch (IOException e) {
			System.err.println(e);
		}
		
	}
	
}
