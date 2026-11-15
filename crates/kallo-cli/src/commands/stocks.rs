//! `kalo stocks` — what is compiled in.

use kallo_core::{FILM_STOCKS, PAPER_STOCKS};

/// Run the subcommand.
pub fn run(json: bool) {
    if json {
        println!("{}", kallo_api::catalogue::json());
        return;
    }

    println!("film stocks");
    for stock in FILM_STOCKS {
        println!("  {:<22} {}", stock.id, stock.label);
        println!("  {:<22} {}", "", stock.note);
    }

    println!();
    println!("paper stocks");
    for stock in PAPER_STOCKS {
        println!("  {:<22} {}", stock.id, stock.label);
        println!("  {:<22} {}", "", stock.note);
    }
}
