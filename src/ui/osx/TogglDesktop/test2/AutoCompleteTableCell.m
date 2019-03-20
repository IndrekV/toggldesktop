//
//  AutoCompleteTableCell.m
//  LiteComplete
//
//  Created by Indrek Vändrik on 20/02/2018.
//  Copyright © 2018 Toggl. All rights reserved.
//

#import "AutoCompleteTableCell.h"
#import "ProjectTextField.h"
#import "TogglDesktop-Swift.h"

@interface AutoCompleteTableCell ()

@property (weak) IBOutlet DotImageView *dotView;
@property (weak) IBOutlet ProjectTextField *projectLbl;

@end

@implementation AutoCompleteTableCell

- (void)render:(AutocompleteItem *)view_item selected:(BOOL)selected
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	[self setFocused:selected];
	self.dotView.hidden = YES;
	self.projectLbl.hidden = YES;
	self.cellDescription.hidden = YES;
	self.cellDescription.toolTip = view_item.Text;
	self.isSelectable = view_item.Type > -1;
	[self.bottomLine setHidden:(view_item.Type != -3)];

	// Render content depend on type of view_item
	[self renderContentWithViewItem:view_item];
}

- (void)setFocused:(BOOL)focus
{
	NSColor *color = [NSColor textBackgroundColor];

	if (focus == YES)
	{
		color = [NSColor selectedTextBackgroundColor];
	}
	[self.backgroundBox setFillColor:color];
}

- (void)renderContentWithViewItem:(AutocompleteItem *)view_item
{
	AutoCompleteCellType cellType = [AutoCompleteTableCell cellTypeFrom:view_item];

	// Category row
	if (cellType == AutoCompleteCellTypeCategory)
	{
		[self renderTitleForCategoryCellWithViewItem:view_item];
		return;
	}

	// Client row / No project row
	if (cellType == AutoCompleteCellTypeClient || cellType == AutoCompleteCellTypeNoProject)
	{
		[self renderTitleForClientCellWithViewItem:view_item];
		return;
	}

	// Workspace row
	if (cellType == AutoCompleteCellTypeWorkspace)
	{
		[self renderTitleForWorkspaceCellWithViewItem:view_item];
		return;
	}

	if (cellType == AutoCompleteCellTypeProject)
	{
		[self renderTitleForProjectCellWithViewItem:view_item];
		return;
	}

	[self renderTitleForTimeEntryCellWithViewItem:view_item];
}

- (void)renderTitleForCategoryCellWithViewItem:(AutocompleteItem *)viewItem {
	NSDictionary *attribute =      @{
			NSFontAttributeName : [NSFont systemFontOfSize:11 weight:NSFontWeightMedium],
			NSForegroundColorAttributeName:[self categoryLabelColor]
	};

	self.cellDescription.hidden = NO;
	self.cellDescription.attributedStringValue = [[NSAttributedString alloc] initWithString:viewItem.Text attributes:attribute];
}

- (void)renderTitleForClientCellWithViewItem:(AutocompleteItem *)viewItem
{
	NSString *spacing = @"  ";
	NSString *text = [NSString stringWithFormat:@"%@%@", spacing, viewItem.Text];
	NSDictionary *attribute = @{
			NSFontAttributeName : [NSFont systemFontOfSize:12],
			NSForegroundColorAttributeName:[NSColor labelColor]
	};

	self.cellDescription.hidden = NO;
	self.cellDescription.attributedStringValue = [[NSAttributedString alloc] initWithString:text attributes:attribute];
}

- (void)renderTitleForWorkspaceCellWithViewItem:(AutocompleteItem *)viewItem
{
	NSMutableParagraphStyle *paragrapStyle = NSMutableParagraphStyle.new;

	paragrapStyle.alignment = kCTTextAlignmentCenter;
	NSDictionary *attribute =  @{
			NSFontAttributeName : [NSFont systemFontOfSize:14],
			NSForegroundColorAttributeName:[NSColor labelColor],
			NSParagraphStyleAttributeName:paragrapStyle
	};

	self.cellDescription.hidden = NO;
	self.cellDescription.attributedStringValue = [[NSAttributedString alloc] initWithString:viewItem.Text attributes:attribute];
}

- (void)renderTitleForProjectCellWithViewItem:(AutocompleteItem *)viewItem
{
	self.dotView.hidden = NO;
	self.projectLbl.hidden = NO;
	[self.projectLbl setTitleWithAutoCompleteItem:viewItem];
}

- (void)renderTitleForTimeEntryCellWithViewItem:(AutocompleteItem *)viewItem
{
}

- (NSColor *)categoryLabelColor
{
	if (@available(macOS 10.13, *))
	{
		return [NSColor colorNamed:@"grey-text-color"];
	}
	else
	{
		return [ConvertHexColor hexCodeToNSColor:@"#555555"];
	}
}

@end
