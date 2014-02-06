
//
//  TimerEditViewController.m
//  kopsik_ui_osx
//
//  Created by Tanel Lebedev on 19/09/2013.
//  Copyright (c) 2013 kopsik developers. All rights reserved.
//

#import "TimerEditViewController.h"
#import "UIEvents.h"
#import "AutocompleteItem.h"
#import "Context.h"
#import "ErrorHandler.h"
#import "AutocompleteDataSource.h"
#import "ConvertHexColor.h"
#import "ModelChange.h"
#import "NSComboBox_Expansion.h"
#import "TimeEntryViewItem.h"

@interface TimerEditViewController ()
@property AutocompleteDataSource *autocompleteDataSource;
@property TimeEntryViewItem *time_entry;
@property NSTimer *timerAutocompleteRendering;
@property NSTimer *timer;
@end

@implementation TimerEditViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      self.autocompleteDataSource = [[AutocompleteDataSource alloc] init];

      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(eventHandler:)
                                                   name:kUIStateTimerRunning
                                                 object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(eventHandler:)
                                                   name:kUIStateTimerStopped
                                                 object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(eventHandler:)
                                                   name:kUIStateUserLoggedIn
                                                 object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(eventHandler:)
                                                   name:kUIEventModelChange
                                                 object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(eventHandler:)
                                                   name:kUICommandEditRunningTimeEntry
                                                 object:nil];

      self.time_entry = [[TimeEntryViewItem alloc] init];
      
      self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                    target:self
                                                  selector:@selector(timerFired:)
                                                  userInfo:nil
                                                   repeats:YES];
    }
    
    return self;
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)partialString {
  return [self.autocompleteDataSource completedString:partialString];
}

- (void)renderAutocomplete {
  NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

  self.timerAutocompleteRendering = nil;

  [self.autocompleteDataSource fetch:YES withTasks:YES withProjects:YES];

  if (self.descriptionComboBox.dataSource == nil) {
    self.descriptionComboBox.usesDataSource = YES;
    self.descriptionComboBox.dataSource = self;
  }
  [self.descriptionComboBox reloadData];
}

- (void) scheduleAutocompleteRendering {
  NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

  if (self.timerAutocompleteRendering != nil) {
    return;
  }
  @synchronized(self) {
    self.timerAutocompleteRendering = [NSTimer scheduledTimerWithTimeInterval:kThrottleSeconds
                                                                       target:self
                                                                     selector:@selector(renderAutocomplete)
                                                                     userInfo:nil
                                                                      repeats:NO];
  }
}

- (void)eventHandler: (NSNotification *) notification {
  if ([notification.name isEqualToString:kUIStateTimerRunning]) {
    self.time_entry = notification.object;
    [self performSelectorOnMainThread:@selector(render)
                           withObject:nil
                        waitUntilDone:NO];
    return;
  }

  if ([notification.name isEqualToString:kUIStateTimerStopped]) {
    self.time_entry = [[TimeEntryViewItem alloc] init];
    [self performSelectorOnMainThread:@selector(render)
                           withObject:nil
                        waitUntilDone:NO];
    return;
  }

  if ([notification.name isEqualToString:kUICommandEditRunningTimeEntry]) {
    if (self.time_entry != nil && self.time_entry.GUID != nil) {
      [[NSNotificationCenter defaultCenter] postNotificationName:kUIStateTimeEntrySelected
                                                        object:self.time_entry.GUID];
    }
    return;
  }
  
  if ([notification.name isEqualToString:kUIStateUserLoggedIn]) {
    [self performSelectorOnMainThread:@selector(scheduleAutocompleteRendering)
                           withObject:nil
                        waitUntilDone:NO];
    return;
  }

  if (![notification.name isEqualToString:kUIEventModelChange]) {
    return;
  }
  
  ModelChange *change = notification.object;
  if (![change.ModelType isEqualToString:@"tag"]) {
    [self performSelectorOnMainThread:@selector(scheduleAutocompleteRendering)
                           withObject:nil
                        waitUntilDone:NO];
  }

  // We only care about time entry changes
  if (! [change.ModelType isEqualToString:@"time_entry"]) {
    return;
  }

  // Handle delete
  if ([change.ChangeType isEqualToString:@"delete"]) {
    // Time entry we thought was running, has been deleted.
    if ([change.GUID isEqualToString:self.time_entry.GUID]) {
      [[NSNotificationCenter defaultCenter] postNotificationName:kUIStateTimerStopped
                                                          object:nil];
    }
    return;
  }

  // Handle update
  TimeEntryViewItem *updated = [TimeEntryViewItem findByGUID:change.GUID];

  // Time entry we thought was running, has been stopped.
  if ((updated.duration_in_seconds >= 0) &&
      [updated.GUID isEqualToString:self.time_entry.GUID]) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kUIStateTimerStopped
                                                        object:nil];
    return;
  }

  // Time entry we did not know was running, is running.
  if ((updated.duration_in_seconds < 0) &&
      ![updated.GUID isEqualToString:self.time_entry.GUID]) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kUIStateTimerRunning
                                                        object:updated];
    return;
  }

  // Time entry is still running and needs to be updated.
  if ((updated.duration_in_seconds < 0) &&
      [updated.GUID isEqualToString:self.time_entry.GUID]) {
    self.time_entry = updated;
    [self performSelectorOnMainThread:@selector(render)
                           withObject:nil
                        waitUntilDone:NO];
    return;
  }
}

- (void) render {
  NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
  
  // Start/stop button title and color depend on
  // whether time entry is running
  if (self.time_entry.duration_in_seconds < 0) {
    self.startButtonLabelTextField.stringValue = @"Stop";
    self.startButtonBox.borderColor = [ConvertHexColor hexCodeToNSColor:@"#ec0000"];
    self.startButtonBox.fillColor = [ConvertHexColor hexCodeToNSColor:@"#ec0000"];
  } else {
    self.startButtonLabelTextField.stringValue = @"Start";
    self.startButtonBox.borderColor = [ConvertHexColor hexCodeToNSColor:@"#4bc800"];
    self.startButtonBox.fillColor = [ConvertHexColor hexCodeToNSColor:@"#4bc800"];
  }

  // Description and duration cannot be edited
  // while time entry is running
  if (self.time_entry.duration_in_seconds < 0) {
    [self.descriptionComboBox setEnabled:NO];
    [self.durationTextField setEnabled:NO];
  } else {
    [self.descriptionComboBox setEnabled:YES];
    [self.durationTextField setEnabled:YES];
  }
  
  // Display description
  if (self.time_entry.Description != nil) {
    self.descriptionComboBox.stringValue = self.time_entry.Description;
  } else {
    self.descriptionComboBox.stringValue = @"";
  }
  
  // If a project is assigned, then project name
  // is visible.
  if (self.time_entry.ProjectID) {
    [self.projectTextField setHidden:NO];
  } else {
    [self.projectTextField setHidden:YES];
  }
  
  // Display project name
  if (self.time_entry.ProjectAndTaskLabel != nil) {
    self.projectTextField.stringValue =
      [self.time_entry.ProjectAndTaskLabel uppercaseString];
  } else {
    self.projectTextField.stringValue = @"";
  }
  self.projectTextField.backgroundColor = [ConvertHexColor hexCodeToNSColor:self.time_entry.color];

  // If a project is selected then description
  // field is higher on the screen.
  NSPoint pt;
  pt.x = self.descriptionComboBox.frame.origin.x;
  if (self.time_entry.ProjectID) {
    pt.y = 16;
  } else {
    pt.y = 8;
  }
  [self.descriptionComboBox setFrameOrigin:pt];
  
  // Display duration
  if (self.time_entry.duration != nil) {
    self.durationTextField.stringValue = self.time_entry.duration;
  } else {
    self.durationTextField.stringValue = @"";
  }
}

-(NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox{
  return [self.autocompleteDataSource count];
}

-(id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)row{
  return [self.autocompleteDataSource keyAtIndex:row];
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)aString {
  return [self.autocompleteDataSource indexOfKey:aString];
}

- (IBAction)startButtonClicked:(id)sender {
  if (self.time_entry.duration_in_seconds < 0) {
    self.durationTextField.stringValue=@"";
    self.descriptionComboBox.stringValue=@"";
    [[NSNotificationCenter defaultCenter] postNotificationName:kUICommandStop
                                                        object:nil];
    return;
  }

  self.time_entry.Duration = self.durationTextField.stringValue;
  self.time_entry.Description = self.descriptionComboBox.stringValue;
  [[NSNotificationCenter defaultCenter] postNotificationName:kUICommandNew
                                                      object:self.time_entry];

  // Reset autocomplete filter
  [self.autocompleteDataSource setFilter:@""];
  [self.descriptionComboBox reloadData];

  // Clear Time entry form fields after stop
  if ([[self.durationTextField stringValue]length]>0){
    self.durationTextField.stringValue=@"";
    self.descriptionComboBox.stringValue=@"";
  }
}

- (IBAction)descriptionComboBoxChanged:(id)sender {

  NSString *key = [self.descriptionComboBox stringValue];
  AutocompleteItem *item = [self.autocompleteDataSource get:key];

  // User has entered free text
  if (item == nil) {
    self.time_entry.Description = [self.descriptionComboBox stringValue];
    return;
  }

  // User has selected a autocomplete item.
  // It could be a time entry, a task or a project.
  self.time_entry.ProjectID = item.ProjectID;
  self.time_entry.TaskID = item.TaskID;
  self.time_entry.Description = item.Text;
  self.time_entry.ProjectAndTaskLabel = item.ProjectAndTaskLabel;

  [self render];
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
  NSComboBox *box = [aNotification object];
  NSString *filter = [box stringValue];
  [self.autocompleteDataSource setFilter:filter];
  [self.descriptionComboBox reloadData];

  if (filter == nil || [filter length] == 0) {
    if ([box isExpanded] == YES) {
      [box setExpanded:NO];
    }
  } else {
    if ([box isExpanded] == NO) {
      [box setExpanded:YES];
    }
  }
}

- (void)timerFired:(NSTimer*)timer {
  if (self.time_entry != nil && self.time_entry.duration_in_seconds < 0) {
    char str[duration_str_len];
    kopsik_format_duration_in_seconds_hhmmss(self.time_entry.duration_in_seconds,
                                             str,
                                             duration_str_len);
    NSString *newValue = [NSString stringWithUTF8String:str];
    [self.durationTextField setStringValue:newValue];
  }
}

@end
