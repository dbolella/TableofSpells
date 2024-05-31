//
//  ContentView.swift
//  TableOfSpells
//
//  Created by Daniel Bolella on 5/28/24.
//

import SwiftUI

struct ContentView: View {
    @State var spells: Spells?
    @State var selectedSpell = Set<Spell.ID>()
    @State var sortOrder: [KeyPathComparator<Spell>] =  [KeyPathComparator(\Spell.name)]
    
    var body: some View {
        Group {
            if let spells {
                Table(of: Spell.self, selection: $selectedSpell, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Incantation"){ spell in
                        if let incantation = spell.incantation{
                            Text(incantation)
                        } else {
                            Text("-")
                        }
                    }
                    TableColumn("Effect", value: \.effect)
                    TableColumn("Verbal"){ spell in
                        if let verbal = spell.canBeVerbal {
                            Image(systemName: verbal ?
                                  "checkmark.circle.fill" :
                                    "x.circle.fill")
                                .foregroundStyle(verbal ? 
                                                 Color.green :
                                                    Color.red)
                        } else {
                            Text("-")
                        }
                    }
                    TableColumn("Type", value: \.type)
                    TableColumn("Light", value: \.light)
                } rows: {
                    ForEach(spells) { spell in
                        TableRow(spell)
                            .contextMenu {                  
                                Button("Copy Spell Name") {
                                    let pb = NSPasteboard.general
                                    pb.declareTypes([.string], owner: nil)
                                    pb.setString(spell.name, forType: .string)
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ContentUnavailableView("Casting the Fetch Spell!",
                                       systemImage: "wand.and.stars")
            }
        }
        .task {
            do {
                spells = try await WizardWorldAPICaller.fetchSpells()
            } catch {
                print("Error")
            }
        }
        .onChange(of: sortOrder, initial: true) { _, newValue in
            spells?.sort(using: newValue)
        }
    }
}

#Preview {
    ContentView()
}
