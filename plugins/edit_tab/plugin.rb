
module Redcar
  class EditTabPlugin < Redcar::Plugin
    UNDO_CLOSE_TAB_DEPTH = 10
    
    cattr_accessor :closed_tabs
    self.closed_tabs = []
    
    def self.load(plugin) #:nodoc:
      Hook.register :tab_changed
      Hook.register :tab_save
      Hook.register :tab_load
      
      Sensitive.register(:edit_tab, 
                         [:open_window, :new_tab, :close_tab, 
                          :after_focus_tab]) do
        Redcar.win and Redcar.tab and Redcar.tab.is_a? EditTab
      end
      
      Sensitive.register(:open_edit_tabs, [:open_window, :new_tab, :close_tab]) do
        Redcar.win and Redcar.win.tabs.any? {|tab| tab.is_a?(EditTab) }
      end

      Sensitive.register(:closed_edit_tab, [:new_tab, :after_close_tab]) do
        Redcar::EditTabPlugin.closed_tabs.any?
      end
      
      Sensitive.register(:modified?, 
                         [:open_window, :new_tab, :close_tab, 
                          :after_focus_tab, :tab_changed, 
                          :after_tab_save]) do
        Redcar.tab and Redcar.tab.is_a? EditTab and Redcar.tab.modified
      end
      
      Sensitive.register(:modified_and_filename?, 
                         [:open_window, :new_tab, :close_tab, 
                          :after_focus_tab, :tab_changed, 
                          :after_tab_save]) do
        Redcar.tab and Redcar.tab.is_a? EditTab and Redcar.tab.modified and Redcar.tab.filename
      end
      
      Hook.attach :after_open_window do
        Redcar::EditTab.create_grammar_combo
        Redcar::EditTab.create_grammar_key_bindings
        Redcar::EditTab.create_line_col_status
      end
      
      Hook.attach :close_tab do |tab|
        if tab.is_a?(EditTab) and not tab.filename.blank?
          self.closed_tabs << {:filename => tab.filename}
          if self.closed_tabs.length == UNDO_CLOSE_TAB_DEPTH
            self.closed_tabs = closed_tabs[1..-1]
          end
        end
      end

      Hook.attach :after_focus_tab do |tab|
        gtk_combo_box = bus('/gtk/window/statusbar/grammar_combo').data
        gtk_line_label = bus('/gtk/window/statusbar/line').data
        if tab and tab.is_a? EditTab
          list = Gtk::Mate::Buffer.bundles.map{|b| b.grammars }.flatten.map(&:name).sort
          gtk_combo_box.sensitive = true
          if tab.document.parser
            gtk_combo_box.active = list.index(tab.document.parser.grammar.name)
          end
          gtk_line_label.sensitive = true
        else
          gtk_combo_box.sensitive = false
          gtk_combo_box.active = -1
          gtk_line_label.sensitive = false
        end
      end
      # 
      # Sensitive.register(:selected_text, 
      #                    [:open_window, :new_tab, :close_tab, 
      #                     :after_focus_tab]) do
      #   win and tab and tab.is_a? EditTab
      # end

      Dir[File.dirname(__FILE__) + "/lib/*"].each {|f| Kernel.load f}
      Dir[File.dirname(__FILE__) + "/tabs/*"].each {|f| Kernel.load f}
      Kernel.load File.dirname(__FILE__) + "/commands/edit_tab_command.rb"
      Kernel.load File.dirname(__FILE__) + "/commands/change_indent_command.rb"
      Kernel.load File.dirname(__FILE__) + "/commands/ruby.rb"
      Dir[File.dirname(__FILE__) + "/commands/*"].each {|f| Kernel.load f}
      Kernel.load File.dirname(__FILE__) + "/widgets/font_chooser_button.rb"
      Kernel.load File.dirname(__FILE__) + "/preferences.rb"
      
      Redcar::Bundle.bundles.each do |bundle|
        bundle.load_snippets_with_class_and_range(Redcar::SnippetCommand, Redcar::EditTab)
        bundle.load_shell_commands_with_range(Redcar::EditTab)
      end
      
      plugin.transition(FreeBASE::LOADED)
    end

    def self.start(plugin) #:nodoc:
      plugin.transition(FreeBASE::RUNNING)
    end

  end
end
